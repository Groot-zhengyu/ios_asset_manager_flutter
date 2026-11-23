import 'package:flutter/foundation.dart';

import '../core/app_settings.dart';
import '../core/decimal.dart';
import '../core/errors.dart';
import '../models/cash_account.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import '../models/forms.dart';
import '../models/fund_plan.dart';
import '../models/fund_screenshot.dart';
import '../models/ocr_draft.dart';
import '../models/recurring_rule.dart';
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
  List<RecurringRule> rules = <RecurringRule>[];
  List<FundPlan> fundPlans = <FundPlan>[];

  bool get appLockEnabled => settings.lockEnabled;
  bool get biometricEnabled => settings.biometricEnabled;
  bool get hasPin => settings.pinHash.isNotEmpty;

  void reload() {
    securities = repository.fetchSecurities();
    vehicles = repository.fetchVehicles();
    cashAccounts = repository.fetchCashAccounts();
    expenses = repository.fetchExpenses();
    drafts = repository.fetchDrafts();
    rules = repository.fetchRules();
    fundPlans = repository.fetchPlans();
    notifyListeners();
  }

  AssetSnapshot get snapshot => AssetCalculator.snapshot(
        securities: securities,
        vehicles: vehicles,
        accounts: cashAccounts,
      );

  /// 支出合计：收入与基金定投扣款不计入日常支出。
  Dec get totalExpense => expenses.fold<Dec>(
        Dec.zero,
        (sum, e) =>
            e.isIncome || e.type == ExpenseType.investment ? sum : sum + e.amount,
      );

  Dec get totalIncome => expenses.fold<Dec>(
        Dec.zero,
        (sum, e) => e.isIncome ? sum + e.amount : sum,
      );

  Dec get totalInvestment => expenses.fold<Dec>(
        Dec.zero,
        (sum, e) => e.type == ExpenseType.investment ? sum + e.amount : sum,
      );

  Dec get netCashFlow => totalIncome - totalExpense - totalInvestment;

  /// 车辆类费用在只有一辆车时默认关联，避免重复手选。
  String? defaultVehicleId({String? preferred}) {
    final candidate = preferred?.trim();
    if (candidate != null && candidate.isNotEmpty) return candidate;
    return vehicles.length == 1 ? vehicles.single.id : null;
  }

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

    // 车辆类费用：已有显式选择优先；未选且仅有一辆车时自动关联。
    final vehicleId = form.type.isVehicle
        ? defaultVehicleId(preferred: form.vehicleId)
        : form.vehicleId;
    final item = Expense(
      id: editing?.id ?? form.sourceId ?? _newId(),
      type: form.type,
      amount: Dec.parse(form.amountText)!,
      occurredAt: form.occurredAt,
      note: form.note,
      source: form.source,
      vehicleId: vehicleId,
      sourceId: form.sourceId,
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
    String? vehicleId,
  }) {
    final amountError = FormErrors.positivePrice(amountText);
    if (amountError != null) return '金额必须大于 0';
    final linkedVehicle = type.isVehicle
        ? defaultVehicleId(preferred: vehicleId)
        : vehicleId;
    return _write(() {
      repository.saveExpense(Expense(
        id: _newId(),
        type: type,
        amount: Dec.parse(amountText)!,
        occurredAt: occurredAt,
        note: note,
        source: ExpenseSource.ocr,
        vehicleId: linkedVehicle,
        createdAt: DateTime.now(),
      ));
      repository.deleteDraft(draft.id);
    });
  }

  // MARK: - 周期收支规则

  String? saveRule(RecurringRuleFormData form, {RecurringRule? editing}) {
    final titleError = FormErrors.required('规则名称', form.title);
    if (titleError != null) return titleError;
    final amountError = FormErrors.positivePrice(form.amountText);
    if (amountError != null) return '金额必须大于 0';
    final day = form.dayOfMonth.clamp(1, 31).toInt();
    final item = RecurringRule(
      id: editing?.id ?? _newId(),
      title: form.title.trim(),
      type: form.type,
      amount: Dec.parse(form.amountText)!,
      dayOfMonth: day,
      note: form.note,
      vehicleId: form.type.isVehicle
          ? defaultVehicleId(preferred: form.vehicleId)
          : null,
      enabled: form.enabled,
      lastAppliedMonth: editing?.lastAppliedMonth,
      createdAt: editing?.createdAt ?? DateTime.now(),
    );
    return _write(() => repository.saveRule(item));
  }

  String? deleteRule(RecurringRule item) => _write(() {
        repository.deleteRule(item.id);
      });

  void setRuleEnabled(RecurringRule item, bool enabled) {
    _write(() => repository.saveRule(item.copyWith(enabled: enabled)));
  }

  /// 执行到期规则：按 月 幂等，同一规则同一月只生成一条记录。
  int applyDueRules({DateTime? now}) {
    final today = now ?? DateTime.now();
    final monthKey = _monthKey(today);
    var created = 0;
    for (final rule in rules) {
      if (!rule.enabled || rule.lastAppliedMonth == monthKey) continue;
      final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
      final dueDay = rule.dayOfMonth.clamp(1, daysInMonth).toInt();
      if (today.day < dueDay) continue;
      final id = 'rule-${rule.id}-$monthKey';
      if (expenses.any((e) => e.id == id)) continue;
      repository.saveExpense(Expense(
        id: id,
        type: rule.type,
        amount: rule.amount,
        occurredAt: DateTime(today.year, today.month, dueDay, 9),
        note: rule.note.isEmpty ? '${rule.title}（周期规则）' : rule.note,
        source: ExpenseSource.rule,
        vehicleId: rule.vehicleId,
        sourceId: rule.id,
      ));
      repository.saveRule(rule.copyWith(lastAppliedMonth: monthKey));
      created += 1;
    }
    if (created > 0) reload();
    return created;
  }

  // MARK: - 基金截图与定投

  /// 从截图草稿生成基金持仓；代码重复时不覆盖用户已有数据。
  String? saveFundFromScreenshot(FundScreenshotDraft draft) {
    final error = draft.validationError;
    if (error != null) return error;
    final code = draft.code!.trim();
    if (securities.any((s) => s.code == code)) {
      return '该基金代码已存在，请直接编辑原持仓';
    }
    final quantity = draft.effectiveQuantity;
    final costNav = draft.derivedCostNav;
    return saveSecurity(SecurityFormData(
      type: SecurityType.fund,
      name: draft.name!.trim(),
      code: code,
      quantityText: quantity.toStringAsFixed(4),
      costPriceText: costNav.toStringAsFixed(4),
      currentPriceText: draft.effectiveCurrentNav.toStringAsFixed(4),
    ));
  }

  String? saveFundPlan(FundPlanFormData form, {FundPlan? editing}) {
    final codeError = FormErrors.required('基金代码', form.fundCode);
    if (codeError != null) return codeError;
    if (!RegExp(r'^\d{6}$').hasMatch(form.fundCode.trim())) {
      return '基金代码需为 6 位数字';
    }
    final nameError = FormErrors.required('基金名称', form.fundName);
    if (nameError != null) return nameError;
    final amountError = FormErrors.positivePrice(form.amountText);
    if (amountError != null) return '定投金额必须大于 0';

    final now = DateTime.now();
    final day = form.dayOfMonth.clamp(1, 31).toInt();
    final weekday = form.weekday.clamp(1, 7).toInt();
    final scheduleChanged = editing != null &&
        (editing.frequency != form.frequency ||
            editing.dayOfMonth != day ||
            (form.frequency == FundPlanFrequency.weekly &&
                editing.weekday != weekday));
    final nextRunDate = editing != null &&
            form.enabled &&
            !scheduleChanged &&
            editing.nextRunDate.isAfter(_dateOnly(now))
        ? editing.nextRunDate
        : _nextRunDate(form.frequency, day, weekday, now);
    final item = FundPlan(
      id: editing?.id ?? _newId(),
      fundCode: form.fundCode.trim(),
      fundName: form.fundName.trim(),
      amount: Dec.parse(form.amountText)!,
      frequency: form.frequency,
      dayOfMonth: day,
      weekday: weekday,
      enabled: form.enabled,
      nextRunDate: nextRunDate,
      lastRunDate: editing?.lastRunDate,
      history: editing?.history ?? const <FundPlanRun>[],
      createdAt: editing?.createdAt ?? now,
    );
    return _write(() => repository.savePlan(item));
  }

  String? deleteFundPlan(FundPlan item) => _write(() {
        repository.deletePlan(item.id);
      });

  /// 恢复时跳过暂停期间错过的扣款日，不补记历史；暂停本身不改写下次日期。
  void setFundPlanEnabled(FundPlan item, bool enabled) {
    final now = DateTime.now();
    final next = !enabled || item.nextRunDate.isAfter(_dateOnly(now))
        ? item.nextRunDate
        : _nextRunDate(
            item.frequency, item.dayOfMonth, item.weekday, now);
    _write(() => repository.savePlan(
          item.copyWith(enabled: enabled, nextRunDate: next),
        ));
  }

  /// 执行到期定投计划：记录扣款并推进下次日期；按计划 id + 日期幂等。
  int applyDueFundPlans({DateTime? now}) {
    final today = now ?? DateTime.now();
    var created = 0;
    for (final plan in fundPlans) {
      if (!plan.enabled || plan.nextRunDate.isAfter(_dateOnly(today))) continue;
      var next = plan.nextRunDate;
      final runs = <FundPlanRun>[...plan.history];
      var guard = 0;
      while (!next.isAfter(_dateOnly(today)) && guard < 24) {
        guard += 1;
        final runId = 'fundplan-${plan.id}-${_dayKey(next)}';
        if (!runs.any((run) => run.id == runId) &&
            !expenses.any((e) => e.id == runId)) {
          repository.saveExpense(Expense(
            id: runId,
            type: ExpenseType.investment,
            amount: plan.amount,
            occurredAt: DateTime(next.year, next.month, next.day, 9),
            note: '${plan.fundName} 定投扣款',
            source: ExpenseSource.fundPlan,
            sourceId: plan.id,
          ));
          runs.add(FundPlanRun(
            id: runId,
            planId: plan.id,
            date: next,
            amount: plan.amount,
            note: '${plan.fundName} 定投扣款',
          ));
          created += 1;
        }
        next = _nextRunDate(
          plan.frequency,
          plan.dayOfMonth,
          plan.weekday,
          next.add(const Duration(days: 1)),
        );
      }
      repository.savePlan(plan.copyWith(
        nextRunDate: next,
        lastRunDate: runs.isEmpty ? plan.lastRunDate : runs.last.date,
        history: runs,
      ));
    }
    if (created > 0) reload();
    return created;
  }

  /// 启动/回前台时统一执行所有到期规则。
  int applyDueItems({DateTime? now}) {
    var created = applyDueRules(now: now);
    created += applyDueFundPlans(now: now);
    return created;
  }

  static String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  static String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _nextRunDate(
    FundPlanFrequency frequency,
    int dayOfMonth,
    int weekday,
    DateTime from,
  ) {
    final anchor = _dateOnly(from).add(const Duration(days: 1));
    if (frequency == FundPlanFrequency.monthly) {
      var year = anchor.year;
      var month = anchor.month;
      final days = DateTime(year, month + 1, 0).day;
      var date = DateTime(year, month, dayOfMonth.clamp(1, days).toInt());
      while (!date.isAfter(anchor)) {
        month += 1;
        if (month > 12) {
          month = 1;
          year += 1;
        }
        final nextDays = DateTime(year, month + 1, 0).day;
        date = DateTime(year, month, dayOfMonth.clamp(1, nextDays).toInt());
      }
      return date;
    }
    final delta = (weekday - anchor.weekday + 7) % 7;
    return anchor.add(Duration(days: delta));
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

  static int _idSequence = 0;

  /// 单调 id：避免同一微秒内连续保存时 id 相同而被仓储 upsert 覆盖。
  static String _newId() {
    _idSequence += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_idSequence';
  }
}
