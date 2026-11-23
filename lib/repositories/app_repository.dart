import 'dart:convert';
import 'dart:io';

import '../core/decimal.dart';
import '../models/cash_account.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import '../models/fund_plan.dart';
import '../models/ocr_draft.dart';
import '../models/recurring_rule.dart';
import '../models/security.dart';
import '../models/vehicle.dart';

/// 全应用统一仓储接口。UI/ViewModel 只依赖此接口，便于内存测试与本地文件持久化互换。
abstract class AppRepository {
  List<Security> fetchSecurities();
  void saveSecurity(Security item);
  void deleteSecurity(String id);

  List<Vehicle> fetchVehicles();
  void saveVehicle(Vehicle item);
  void deleteVehicle(String id);

  List<CashAccount> fetchCashAccounts();
  void saveCashAccount(CashAccount item);
  void deleteCashAccount(String id);

  List<Expense> fetchExpenses();
  void saveExpense(Expense item);
  void deleteExpense(String id);

  List<OCRDraft> fetchDrafts();
  void saveDraft(OCRDraft item);
  void deleteDraft(String id);

  List<RecurringRule> fetchRules();
  void saveRule(RecurringRule item);
  void deleteRule(String id);

  List<FundPlan> fetchPlans();
  void savePlan(FundPlan item);
  void deletePlan(String id);

  void persist();
}

/// 内存实现，供单元测试与 widget 测试使用。
class InMemoryAppRepository implements AppRepository {
  final List<Security> _securities = [];
  final List<Vehicle> _vehicles = [];
  final List<CashAccount> _cashAccounts = [];
  final List<Expense> _expenses = [];
  final List<OCRDraft> _drafts = [];
  final List<RecurringRule> _rules = [];
  final List<FundPlan> _plans = [];

  bool shouldThrowOnSave = false;

  void _check() {
    if (shouldThrowOnSave) throw StateError('disk full');
  }

  @override
  List<Security> fetchSecurities() => List.unmodifiable(_securities);
  @override
  void saveSecurity(Security item) {
    _check();
    _upsert(_securities, item.id, item);
  }

  @override
  void deleteSecurity(String id) => _securities.removeWhere((e) => e.id == id);

  @override
  List<Vehicle> fetchVehicles() => List.unmodifiable(_vehicles);
  @override
  void saveVehicle(Vehicle item) {
    _check();
    _upsert(_vehicles, item.id, item);
  }

  @override
  void deleteVehicle(String id) {
    _vehicles.removeWhere((e) => e.id == id);
    _expenses.removeWhere((e) => e.vehicleId == id);
  }

  @override
  List<CashAccount> fetchCashAccounts() => List.unmodifiable(_cashAccounts);
  @override
  void saveCashAccount(CashAccount item) {
    _check();
    _upsert(_cashAccounts, item.id, item);
  }

  @override
  void deleteCashAccount(String id) =>
      _cashAccounts.removeWhere((e) => e.id == id);

  @override
  List<Expense> fetchExpenses() => List.unmodifiable(_expenses);
  @override
  void saveExpense(Expense item) {
    _check();
    _upsert(_expenses, item.id, item);
  }

  @override
  void deleteExpense(String id) => _expenses.removeWhere((e) => e.id == id);

  @override
  List<OCRDraft> fetchDrafts() => List.unmodifiable(_drafts);
  @override
  void saveDraft(OCRDraft item) {
    _check();
    _upsert(_drafts, item.id, item);
  }

  @override
  void deleteDraft(String id) => _drafts.removeWhere((e) => e.id == id);

  @override
  List<RecurringRule> fetchRules() => List.unmodifiable(_rules);
  @override
  void saveRule(RecurringRule item) {
    _check();
    _upsert(_rules, item.id, item);
  }

  @override
  void deleteRule(String id) => _rules.removeWhere((e) => e.id == id);

  @override
  List<FundPlan> fetchPlans() => List.unmodifiable(_plans);
  @override
  void savePlan(FundPlan item) {
    _check();
    _upsert(_plans, item.id, item);
  }

  @override
  void deletePlan(String id) => _plans.removeWhere((e) => e.id == id);

  @override
  void persist() {}

  static void _upsert<T>(List<T> list, String id, T item) {
    final index = list.indexWhere((e) => (e as dynamic).id as String == id);
    if (index >= 0) {
      list[index] = item;
    } else {
      list.add(item);
    }
  }
}

/// JSON 文件持久化实现。目录由上层注入（Android/iOS 用应用文档目录）。
class JsonAppRepository implements AppRepository {
  JsonAppRepository(this.file);

  final File file;
  List<Security> _securities = [];
  List<Vehicle> _vehicles = [];
  List<CashAccount> _cashAccounts = [];
  List<Expense> _expenses = [];
  List<OCRDraft> _drafts = [];
  List<RecurringRule> _rules = [];
  List<FundPlan> _plans = [];

  bool shouldThrowOnSave = false;

  void load() {
    if (!file.existsSync()) return;
    try {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      _securities = (data['securities'] as List? ?? [])
          .map((e) => _securityFromJson(e as Map<String, dynamic>))
          .toList();
      _vehicles = (data['vehicles'] as List? ?? [])
          .map((e) => _vehicleFromJson(e as Map<String, dynamic>))
          .toList();
      _cashAccounts = (data['cashAccounts'] as List? ?? [])
          .map((e) => _cashFromJson(e as Map<String, dynamic>))
          .toList();
      _expenses = (data['expenses'] as List? ?? [])
          .map((e) => _expenseFromJson(e as Map<String, dynamic>))
          .toList();
      _drafts = (data['drafts'] as List? ?? [])
          .map((e) => _draftFromJson(e as Map<String, dynamic>))
          .toList();
      _rules = (data['recurringRules'] as List? ?? [])
          .map((e) => _ruleFromJson(e as Map<String, dynamic>))
          .toList();
      _plans = (data['fundPlans'] as List? ?? [])
          .map((e) => _planFromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // 文件损坏时从空数据启动，避免应用崩溃。
    }
  }

  @override
  void persist() {
    if (shouldThrowOnSave) throw StateError('disk full');
    final data = <String, dynamic>{
      'securities': _securities.map(_securityToJson).toList(),
      'vehicles': _vehicles.map(_vehicleToJson).toList(),
      'cashAccounts': _cashAccounts.map(_cashToJson).toList(),
      'expenses': _expenses.map(_expenseToJson).toList(),
      'drafts': _drafts.map(_draftToJson).toList(),
      'recurringRules': _rules.map(_ruleToJson).toList(),
      'fundPlans': _plans.map(_planToJson).toList(),
    };
    file.writeAsStringSync(jsonEncode(data));
  }

  void _check() {
    if (shouldThrowOnSave) throw StateError('disk full');
  }

  @override
  List<Security> fetchSecurities() => List.unmodifiable(_securities);
  @override
  void saveSecurity(Security item) {
    _check();
    InMemoryAppRepository._upsert(_securities, item.id, item);
    persist();
  }

  @override
  void deleteSecurity(String id) {
    _securities.removeWhere((e) => e.id == id);
    persist();
  }

  @override
  List<Vehicle> fetchVehicles() => List.unmodifiable(_vehicles);
  @override
  void saveVehicle(Vehicle item) {
    _check();
    InMemoryAppRepository._upsert(_vehicles, item.id, item);
    persist();
  }

  @override
  void deleteVehicle(String id) {
    _vehicles.removeWhere((e) => e.id == id);
    _expenses.removeWhere((e) => e.vehicleId == id);
    persist();
  }

  @override
  List<CashAccount> fetchCashAccounts() => List.unmodifiable(_cashAccounts);
  @override
  void saveCashAccount(CashAccount item) {
    _check();
    InMemoryAppRepository._upsert(_cashAccounts, item.id, item);
    persist();
  }

  @override
  void deleteCashAccount(String id) {
    _cashAccounts.removeWhere((e) => e.id == id);
    persist();
  }

  @override
  List<Expense> fetchExpenses() => List.unmodifiable(_expenses);
  @override
  void saveExpense(Expense item) {
    _check();
    InMemoryAppRepository._upsert(_expenses, item.id, item);
    persist();
  }

  @override
  void deleteExpense(String id) {
    _expenses.removeWhere((e) => e.id == id);
    persist();
  }

  @override
  List<OCRDraft> fetchDrafts() => List.unmodifiable(_drafts);
  @override
  void saveDraft(OCRDraft item) {
    _check();
    InMemoryAppRepository._upsert(_drafts, item.id, item);
    persist();
  }

  @override
  void deleteDraft(String id) {
    _drafts.removeWhere((e) => e.id == id);
    persist();
  }

  @override
  List<RecurringRule> fetchRules() => List.unmodifiable(_rules);
  @override
  void saveRule(RecurringRule item) {
    _check();
    InMemoryAppRepository._upsert(_rules, item.id, item);
    persist();
  }

  @override
  void deleteRule(String id) {
    _rules.removeWhere((e) => e.id == id);
    persist();
  }

  @override
  List<FundPlan> fetchPlans() => List.unmodifiable(_plans);
  @override
  void savePlan(FundPlan item) {
    _check();
    InMemoryAppRepository._upsert(_plans, item.id, item);
    persist();
  }

  @override
  void deletePlan(String id) {
    _plans.removeWhere((e) => e.id == id);
    persist();
  }

  Map<String, dynamic> _securityToJson(Security e) => {
        'id': e.id,
        'type': e.type.rawValue,
        'name': e.name,
        'code': e.code,
        'quantity': e.quantity.toJson(),
        'costPrice': e.costPrice.toJson(),
        'currentPrice': e.currentPrice.toJson(),
        'updatedAt': e.updatedAt.toIso8601String(),
      };

  Security _securityFromJson(Map<String, dynamic> j) => Security(
        id: j['id'] as String,
        type: SecurityTypeX.fromRaw(j['type'] as String),
        name: j['name'] as String,
        code: j['code'] as String,
        quantity: Dec.fromJson(j['quantity'] as String),
        costPrice: Dec.fromJson(j['costPrice'] as String),
        currentPrice: Dec.fromJson(j['currentPrice'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );

  Map<String, dynamic> _vehicleToJson(Vehicle e) => {
        'id': e.id,
        'model': e.model,
        'plateNumber': e.plateNumber,
        'purchasePrice': e.purchasePrice.toJson(),
        'currentValuation': e.currentValuation.toJson(),
        'purchaseDate': e.purchaseDate.toIso8601String(),
        'note': e.note,
      };

  Vehicle _vehicleFromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'] as String,
        model: j['model'] as String,
        plateNumber: j['plateNumber'] as String,
        purchasePrice: Dec.fromJson(j['purchasePrice'] as String),
        currentValuation: Dec.fromJson(j['currentValuation'] as String),
        purchaseDate: DateTime.parse(j['purchaseDate'] as String),
        note: j['note'] as String? ?? '',
      );

  Map<String, dynamic> _cashToJson(CashAccount e) => {
        'id': e.id,
        'name': e.name,
        'balance': e.balance.toJson(),
        'updatedAt': e.updatedAt.toIso8601String(),
      };

  CashAccount _cashFromJson(Map<String, dynamic> j) => CashAccount(
        id: j['id'] as String,
        name: j['name'] as String,
        balance: Dec.fromJson(j['balance'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );

  Map<String, dynamic> _expenseToJson(Expense e) => {
        'id': e.id,
        'type': e.type.rawValue,
        'amount': e.amount.toJson(),
        'occurredAt': e.occurredAt.toIso8601String(),
        'note': e.note,
        'source': e.source.rawValue,
        'relatedAssetId': e.relatedAssetId,
        'vehicleId': e.vehicleId,
        'sourceId': e.sourceId,
        'createdAt': e.createdAt.toIso8601String(),
      };

  Expense _expenseFromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        type: ExpenseTypeX.fromRaw(j['type'] as String),
        amount: Dec.fromJson(j['amount'] as String),
        occurredAt: DateTime.parse(j['occurredAt'] as String),
        note: j['note'] as String? ?? '',
        source: ExpenseSourceX.fromRaw(j['source'] as String?),
        relatedAssetId: j['relatedAssetId'] as String?,
        vehicleId: j['vehicleId'] as String?,
        sourceId: j['sourceId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  Map<String, dynamic> _draftToJson(OCRDraft e) => {
        'id': e.id,
        'image': e.originalImageBytes == null
            ? null
            : base64Encode(e.originalImageBytes!),
        'type': e.recognizedType?.rawValue,
        'amount': e.recognizedAmount?.toJson(),
        'date': e.recognizedDate?.toIso8601String(),
        'note': e.note,
        'confidence': e.confidence,
        'isConfirmed': e.isConfirmed,
        'createdAt': e.createdAt.toIso8601String(),
      };

  OCRDraft _draftFromJson(Map<String, dynamic> j) => OCRDraft(
        id: j['id'] as String,
        originalImageBytes: j['image'] == null
            ? null
            : base64Decode(j['image'] as String),
        recognizedType: j['type'] == null
            ? null
            : ExpenseTypeX.fromRaw(j['type'] as String),
        recognizedAmount: j['amount'] == null
            ? null
            : Dec.fromJson(j['amount'] as String),
        recognizedDate:
            j['date'] == null ? null : DateTime.parse(j['date'] as String),
        note: j['note'] as String?,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        isConfirmed: j['isConfirmed'] as bool? ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  Map<String, dynamic> _ruleToJson(RecurringRule e) => {
        'id': e.id,
        'title': e.title,
        'type': e.type.rawValue,
        'amount': e.amount.toJson(),
        'dayOfMonth': e.dayOfMonth,
        'note': e.note,
        'vehicleId': e.vehicleId,
        'enabled': e.enabled,
        'lastAppliedMonth': e.lastAppliedMonth,
        'createdAt': e.createdAt.toIso8601String(),
      };

  RecurringRule _ruleFromJson(Map<String, dynamic> j) => RecurringRule(
        id: j['id'] as String,
        title: j['title'] as String? ?? '周期记账',
        type: ExpenseTypeX.fromRaw(j['type'] as String?),
        amount: Dec.fromJson(j['amount'] as String? ?? '0'),
        dayOfMonth: _intClamped(j['dayOfMonth'], 1, 31),
        note: j['note'] as String? ?? '',
        vehicleId: j['vehicleId'] as String?,
        enabled: j['enabled'] as bool? ?? true,
        lastAppliedMonth: j['lastAppliedMonth'] as String?,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> _planToJson(FundPlan e) => {
        'id': e.id,
        'fundCode': e.fundCode,
        'fundName': e.fundName,
        'amount': e.amount.toJson(),
        'frequency': e.frequency.rawValue,
        'dayOfMonth': e.dayOfMonth,
        'weekday': e.weekday,
        'enabled': e.enabled,
        'nextRunDate': e.nextRunDate.toIso8601String(),
        'lastRunDate': e.lastRunDate?.toIso8601String(),
        'history': e.history
            .map(
              (run) => <String, dynamic>{
                'id': run.id,
                'planId': run.planId,
                'date': run.date.toIso8601String(),
                'amount': run.amount.toJson(),
                'note': run.note,
              },
            )
            .toList(),
        'createdAt': e.createdAt.toIso8601String(),
      };

  FundPlan _planFromJson(Map<String, dynamic> j) => FundPlan(
        id: j['id'] as String,
        fundCode: j['fundCode'] as String? ?? '',
        fundName: j['fundName'] as String? ?? '',
        amount: Dec.fromJson(j['amount'] as String? ?? '0'),
        frequency: FundPlanFrequencyX.fromRaw(j['frequency'] as String?),
        dayOfMonth: _intClamped(j['dayOfMonth'], 1, 31),
        weekday: _intClamped(j['weekday'], 1, 7),
        enabled: j['enabled'] as bool? ?? true,
        nextRunDate: DateTime.tryParse(j['nextRunDate'] as String? ?? '') ??
            DateTime.now(),
        lastRunDate: j['lastRunDate'] == null
            ? null
            : DateTime.tryParse(j['lastRunDate'] as String),
        history: (j['history'] as List? ?? [])
            .map(
              (run) => FundPlanRun(
                id: run['id'] as String,
                planId: run['planId'] as String,
                date: DateTime.parse(run['date'] as String),
                amount: Dec.fromJson(run['amount'] as String),
                note: run['note'] as String? ?? '',
              ),
            )
            .toList(),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  static int _intClamped(Object? value, int min, int max) {
    final parsed = (value as num?)?.toInt() ?? min;
    return parsed.clamp(min, max).toInt();
  }
}
