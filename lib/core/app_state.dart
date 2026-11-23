import 'package:flutter/foundation.dart';

import '../core/app_settings.dart';
import '../core/decimal.dart';
import '../core/errors.dart';
import '../models/cash_account.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import '../models/forms.dart';
import '../models/ocr_draft.dart';
import '../models/security.dart';
import '../models/vehicle.dart';
import '../repositories/app_repository.dart';
import '../services/asset_calculator.dart';
import '../services/data_transfer_service.dart';
import '../services/market_data_service.dart';

/// 网络行情刷新结果，供 UI 展示「更新 N 条 / 失败 M 条」。
class MarketRefreshResult {
  MarketRefreshResult({
    required this.updated,
    required this.fetched,
    required this.failures,
  });

  /// 价格真正发生变化的条数。
  final int updated;

  /// 成功拿到有效报价的条数（含价格未变的），用于区分「刷新失败」和「价格没动」。
  final int fetched;

  final List<MarketQuoteFailure> failures;

  bool get hasFailures => failures.isNotEmpty;

  /// 全部报价都取到、但价格与上次一致。
  bool get unchangedOnly => fetched > 0 && updated == 0;

  /// 一条报价都没取到（网络异常或代码全错）。
  bool get nothingFetched => fetched == 0;

  /// 统一给用户看的刷新结论，避免「已更新 0 条」这种看起来像失败的提示。
  String summarize() {
    final failureText =
        hasFailures ? '，失败 ${failures.length} 条（已保留上次有效价）' : '';
    if (nothingFetched) {
      if (hasFailures) return '未取到行情$failureText';
      return '没有需要刷新的持仓';
    }
    if (unchangedOnly) return '行情已刷新，$fetched 条价格无变化$failureText';
    return '已更新 $updated 条$failureText';
  }
}

/// 全应用状态中心：所有写操作返回 String?（nil=成功，文案=就地错误反馈）。
/// 口径与 SwiftUI 版保持一致：费用不计入总资产，现价必须 > 0，删除车辆级联清理费用。
class AppState extends ChangeNotifier {
  AppState(this.repository, {AppSettingsStore? settings})
      : settings = settings ?? InMemoryAppSettingsStore() {
    reload();
  }

  final AppRepository repository;

  /// App 锁、生物识别、行情源的持久化设置（重启后仍然生效）。
  final AppSettingsStore settings;

  List<Security> securities = <Security>[];
  List<Vehicle> vehicles = <Vehicle>[];
  List<CashAccount> cashAccounts = <CashAccount>[];
  List<Expense> expenses = <Expense>[];
  List<OCRDraft> drafts = <OCRDraft>[];

  bool get appLockEnabled => settings.lockEnabled;
  bool get biometricEnabled => settings.biometricEnabled;
  bool get hasPin => settings.pinHash.isNotEmpty;

  void reload() {
    securities = repository.fetchSecurities();
    vehicles = repository.fetchVehicles();
    cashAccounts = repository.fetchCashAccounts();
    expenses = repository.fetchExpenses();
    drafts = repository.fetchDrafts();
    notifyListeners();
  }

  AssetSnapshot get snapshot => AssetCalculator.snapshot(
        securities: securities,
        vehicles: vehicles,
        accounts: cashAccounts,
      );

  Dec get totalExpense => expenses.fold<Dec>(
        Dec.zero,
        (sum, e) => sum + e.amount,
      );

  // MARK: - 证券

  String? saveSecurity(SecurityFormData form, {Security? editing}) {
    final nameError = FormErrors.required('名称', form.name);
    if (nameError != null) return nameError;
    final codeError = FormErrors.required('代码', form.code);
    if (codeError != null) return codeError;
    final quantityError = FormErrors.nonNegative('数量', form.quantityText);
    if (quantityError != null) return quantityError;
    final costError = FormErrors.nonNegative('成本价', form.costPriceText);
    if (costError != null) return costError;
    final priceError = FormErrors.positivePrice(form.currentPriceText);
    if (priceError != null) return priceError;

    final item = Security(
      id: editing?.id ?? _newId(),
      type: form.type,
      name: form.name.trim(),
      code: form.code.trim(),
      quantity: Dec.parse(form.quantityText)!,
      costPrice: Dec.parse(form.costPriceText)!,
      currentPrice: Dec.parse(form.currentPriceText)!,
      updatedAt: DateTime.now(),
    );
    return _write(() => repository.saveSecurity(item));
  }

  String? updateCurrentPrice(Security security, String priceText) {
    final error = FormErrors.positivePrice(priceText);
    if (error != null) return error;
    final updated = Security(
      id: security.id,
      type: security.type,
      name: security.name,
      code: security.code,
      quantity: security.quantity,
      costPrice: security.costPrice,
      currentPrice: Dec.parse(priceText)!,
      updatedAt: DateTime.now(),
    );
    return _write(() => repository.saveSecurity(updated));
  }

  /// 手动行情刷新：只接受 >0 的价格，失败保留原值。
  int refreshPrices(Map<String, String> pricesByCode) {
    var updated = 0;
    for (final security in securities) {
      final text = pricesByCode[security.code];
      if (text == null || FormErrors.positivePrice(text) != null) continue;
      final price = Dec.parse(text)!;
      if (price.compareTo(security.currentPrice) == 0) continue;
      repository.saveSecurity(Security(
        id: security.id,
        type: security.type,
        name: security.name,
        code: security.code,
        quantity: security.quantity,
        costPrice: security.costPrice,
        currentPrice: price,
        updatedAt: DateTime.now(),
      ));
      updated += 1;
    }
    reload();
    return updated;
  }

  String? deleteSecurity(Security item) => _write(() {
        repository.deleteSecurity(item.id);
      });

  // MARK: - 车辆

  String? saveVehicle(VehicleFormData form, {Vehicle? editing}) {
    final modelError = FormErrors.required('车型', form.model);
    if (modelError != null) return modelError;
    final plateError = FormErrors.required('牌照', form.plateNumber);
    if (plateError != null) return plateError;
    final purchaseError =
        FormErrors.nonNegative('购入价', form.purchasePriceText);
    if (purchaseError != null) return purchaseError;
    final valuationError =
        FormErrors.nonNegative('当前估值', form.currentValuationText);
    if (valuationError != null) return valuationError;

    final item = Vehicle(
      id: editing?.id ?? _newId(),
      model: form.model.trim(),
      plateNumber: form.plateNumber.trim(),
      purchasePrice: Dec.parse(form.purchasePriceText)!,
      currentValuation: Dec.parse(form.currentValuationText)!,
      purchaseDate: form.purchaseDate,
      note: form.note,
    );
    return _write(() => repository.saveVehicle(item));
  }

  String? deleteVehicle(Vehicle item) => _write(() {
        repository.deleteVehicle(item.id);
      });

  // MARK: - 现金账户

  String? saveCashAccount(CashAccountFormData form, {CashAccount? editing}) {
    final nameError = FormErrors.required('名称', form.name);
    if (nameError != null) return nameError;
    final balanceError = FormErrors.nonNegative('余额', form.balanceText);
    if (balanceError != null) return balanceError;

    final item = CashAccount(
      id: editing?.id ?? _newId(),
      name: form.name.trim(),
      balance: Dec.parse(form.balanceText)!,
      updatedAt: DateTime.now(),
    );
    return _write(() => repository.saveCashAccount(item));
  }

  String? deleteCashAccount(CashAccount item) => _write(() {
        repository.deleteCashAccount(item.id);
      });

  // MARK: - 费用

  String? saveExpense(ExpenseFormData form, {Expense? editing}) {
    final amountError = FormErrors.positivePrice(form.amountText);
    if (amountError != null) return '金额必须大于 0';

    final item = Expense(
      id: editing?.id ?? _newId(),
      type: form.type,
      amount: Dec.parse(form.amountText)!,
      occurredAt: form.occurredAt,
      note: form.note,
      source: form.source,
      vehicleId: form.vehicleId,
      createdAt: editing?.createdAt ?? DateTime.now(),
    );
    return _write(() => repository.saveExpense(item));
  }

  String? deleteExpense(Expense item) => _write(() {
        repository.deleteExpense(item.id);
      });

  Dec expenseTotal({DateTime? from, DateTime? to}) => expenses.fold<Dec>(
        Dec.zero,
        (sum, e) {
          if (from != null && e.occurredAt.isBefore(from)) return sum;
          if (to != null && e.occurredAt.isAfter(to)) return sum;
          return sum + e.amount;
        },
      );

  // MARK: - OCR 草稿

  String? saveDraft(OCRDraft draft) => _write(() => repository.saveDraft(draft));

  String? deleteDraft(OCRDraft draft) => _write(() {
        repository.deleteDraft(draft.id);
      });

  /// OCR 确认：单事务生成 Expense 并清理草稿，失败不留半成品。
  String? confirmDraft(
    OCRDraft draft, {
    required ExpenseType type,
    required String amountText,
    required DateTime occurredAt,
    required String note,
  }) {
    final amountError = FormErrors.positivePrice(amountText);
    if (amountError != null) return '金额必须大于 0';
    return _write(() {
      repository.saveExpense(Expense(
        id: _newId(),
        type: type,
        amount: Dec.parse(amountText)!,
        occurredAt: occurredAt,
        note: note,
        source: ExpenseSource.ocr,
        createdAt: DateTime.now(),
      ));
      repository.deleteDraft(draft.id);
    });
  }

  // MARK: - App 锁

  /// 开启时写入 PIN（只存哈希），关闭时清除 PIN。
  void setAppLock(bool enabled, {String pin = ''}) {
    settings.save(
      lockEnabled: enabled,
      pin: enabled && pin.isNotEmpty ? pin : null,
      clearPin: !enabled,
    );
    notifyListeners();
  }

  void setBiometricEnabled(bool enabled) {
    settings.save(biometricEnabled: enabled);
    notifyListeners();
  }

  /// 未开启锁时恒为 true；开启后按哈希比对。
  bool verifyPin(String input) {
    if (!settings.lockEnabled) return true;
    if (settings.pinHash.isEmpty) return true;
    return pinHashOf(input.trim()) == settings.pinHash;
  }

  // MARK: - 网络行情

  /// 从真实行情源拉取现价。只有 > 0 的价格会写回，失败保留上次有效值。
  Future<MarketRefreshResult> refreshPricesFromNetwork({
    MarketDataService? service,
  }) async {
    final market = service ?? MarketDataService();
    final outcome = await market.fetchPrices(securities);
    var updated = 0;
    var fetched = 0;
    final failures = <MarketQuoteFailure>[...outcome.failures];

    for (final security in securities) {
      final price = outcome.prices[security.code];
      if (price == null) continue;
      fetched += 1;
      if (price.compareTo(security.currentPrice) == 0) continue;
      try {
        repository.saveSecurity(Security(
          id: security.id,
          type: security.type,
          name: security.name,
          code: security.code,
          quantity: security.quantity,
          costPrice: security.costPrice,
          currentPrice: price,
          updatedAt: DateTime.now(),
        ));
        updated += 1;
      } catch (error) {
        // 写库失败：不把错误价格留在内存里，统一以磁盘为准重新加载。
        failures.add(MarketQuoteFailure(security.code, '保存失败：$error'));
      }
    }
    reload();
    return MarketRefreshResult(
      updated: updated,
      fetched: fetched,
      failures: failures,
    );
  }

  // MARK: - 数据导入

  /// 导入原版 SwiftUI 版导出的 JSON / CSV（或本应用的 assets.json）。
  ImportOutcome importData(String text) {
    final outcome = DataTransferService(repository).importFromText(text);
    reload();
    return outcome;
  }

  String? _write(void Function() action) {
    try {
      action();
    } catch (error) {
      notifyListeners();
      return '保存失败：$error';
    }
    reload();
    return null;
  }

  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
