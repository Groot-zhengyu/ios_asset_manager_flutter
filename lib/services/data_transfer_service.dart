import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/decimal.dart';
import '../models/cash_account.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import '../models/fund_plan.dart';
import '../models/recurring_rule.dart';
import '../models/security.dart';
import '../models/vehicle.dart';
import '../repositories/app_repository.dart';

/// 导出结果摘要。
class ExportBundle {
  const ExportBundle({required this.csv, required this.json});

  final String csv;
  final String json;
}

/// 导入统计。
class ImportOutcome {
  ImportOutcome({
    this.securities = 0,
    this.vehicles = 0,
    this.expenses = 0,
    this.cashAccounts = 0,
    this.recurringRules = 0,
    this.fundPlans = 0,
    this.skipped = 0,
  });

  final int securities;
  final int vehicles;
  final int expenses;
  final int cashAccounts;
  final int recurringRules;
  final int fundPlans;
  final int skipped;

  int get total =>
      securities + vehicles + expenses + cashAccounts + recurringRules + fundPlans;

  String get summary =>
      '导入完成：证券 $securities、车辆 $vehicles、费用 $expenses'
      '${cashAccounts > 0 ? '、现金 $cashAccounts' : ''}'
      '${recurringRules > 0 ? '、周期规则 $recurringRules' : ''}'
      '${fundPlans > 0 ? '、定投计划 $fundPlans' : ''}'
      '${skipped > 0 ? '，跳过 $skipped 条' : ''}';
}

/// 数据导入导出：格式与原 SwiftUI 版 `DataExportService` 完全对齐，
/// 因此原版导出的 JSON / CSV 可以直接导进 Flutter 版（双向互通）。
class DataTransferService {
  DataTransferService(this.repository);

  final AppRepository repository;

  // MARK: - 导出

  ExportBundle buildBundle({
    required List<Security> securities,
    required List<Vehicle> vehicles,
    required List<Expense> expenses,
    required List<CashAccount> cashAccounts,
    List<RecurringRule> recurringRules = const <RecurringRule>[],
    List<FundPlan> fundPlans = const <FundPlan>[],
  }) {
    return ExportBundle(
      csv: buildCsv(
        securities: securities,
        vehicles: vehicles,
        expenses: expenses,
      ),
      json: buildJson(
        securities: securities,
        vehicles: vehicles,
        expenses: expenses,
        cashAccounts: cashAccounts,
        recurringRules: recurringRules,
        fundPlans: fundPlans,
      ),
    );
  }

  /// CSV 三段式，表头与字段顺序与原版一致。
  String buildCsv({
    required List<Security> securities,
    required List<Vehicle> vehicles,
    required List<Expense> expenses,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('# 费用记录');
    buffer.writeln(
      'id,type,amount,occurredAt,note,source,relatedAssetId,vehicleId,vehiclePlate,createdAt',
    );
    for (final e in expenses) {
      final vehicle = _vehicleById(vehicles, e.vehicleId);
      buffer.writeln(<String>[
        _cell(e.id),
        _cell(e.type.rawValue),
        _cell(e.amount.plainAmountString),
        _cell(e.occurredAt.toUtc().toIso8601String()),
        _cell(e.note),
        _cell(e.source.rawValue),
        _cell(e.relatedAssetId ?? ''),
        _cell(e.vehicleId ?? ''),
        _cell(vehicle?.plateNumber ?? ''),
        _cell(e.createdAt.toUtc().toIso8601String()),
      ].join(','));
    }

    buffer.writeln('# 证券持仓');
    buffer.writeln('id,type,name,code,quantity,costPrice,currentPrice,updatedAt');
    for (final s in securities) {
      buffer.writeln(<String>[
        _cell(s.id),
        _cell(s.type.rawValue),
        _cell(s.name),
        _cell(s.code),
        _cell(s.quantity.plainAmountString),
        _cell(s.costPrice.plainAmountString),
        _cell(s.currentPrice.plainAmountString),
        _cell(s.updatedAt.toUtc().toIso8601String()),
      ].join(','));
    }

    buffer.writeln('# 车辆资产');
    buffer.writeln(
      'id,model,plateNumber,purchasePrice,currentValuation,purchaseDate,note',
    );
    for (final v in vehicles) {
      buffer.writeln(<String>[
        _cell(v.id),
        _cell(v.model),
        _cell(v.plateNumber),
        _cell(v.purchasePrice.plainAmountString),
        _cell(v.currentValuation.plainAmountString),
        _cell(v.purchaseDate.toUtc().toIso8601String()),
        _cell(v.note),
      ].join(','));
    }
    return buffer.toString();
  }

  /// JSON 与 Swift 版 `ExportDocument` 同构；额外附带 cashAccounts 便于自迁移。
  String buildJson({
    required List<Security> securities,
    required List<Vehicle> vehicles,
    required List<Expense> expenses,
    required List<CashAccount> cashAccounts,
    List<RecurringRule> recurringRules = const <RecurringRule>[],
    List<FundPlan> fundPlans = const <FundPlan>[],
  }) {
    final vehiclesById = {for (final v in vehicles) v.id: v};
    final document = <String, dynamic>{
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'currency': 'CNY',
      'expenses': expenses
          .map((e) => <String, dynamic>{
                'id': e.id,
                'type': e.type.rawValue,
                'amount': e.amount.plainAmountString,
                'occurredAt': e.occurredAt.toUtc().toIso8601String(),
                'note': e.note,
                'source': e.source.rawValue,
                'relatedAssetId': e.relatedAssetId,
                'vehicleId': e.vehicleId,
                'vehiclePlate': vehiclesById[e.vehicleId]?.plateNumber,
                'createdAt': e.createdAt.toUtc().toIso8601String(),
              })
          .toList(),
      'securities': securities
          .map((s) => <String, dynamic>{
                'id': s.id,
                'type': s.type.rawValue,
                'name': s.name,
                'code': s.code,
                'quantity': s.quantity.plainAmountString,
                'costPrice': s.costPrice.plainAmountString,
                'currentPrice': s.currentPrice.plainAmountString,
                'updatedAt': s.updatedAt.toUtc().toIso8601String(),
              })
          .toList(),
      'vehicles': vehicles
          .map((v) => <String, dynamic>{
                'id': v.id,
                'model': v.model,
                'plateNumber': v.plateNumber,
                'purchasePrice': v.purchasePrice.plainAmountString,
                'currentValuation': v.currentValuation.plainAmountString,
                'purchaseDate': v.purchaseDate.toUtc().toIso8601String(),
                'note': v.note,
              })
          .toList(),
      'cashAccounts': cashAccounts
          .map((a) => <String, dynamic>{
                'id': a.id,
                'name': a.name,
                'balance': a.balance.plainAmountString,
                'updatedAt': a.updatedAt.toUtc().toIso8601String(),
              })
          .toList(),
      'recurringRules': recurringRules
          .map((r) => <String, dynamic>{
                'id': r.id,
                'title': r.title,
                'type': r.type.rawValue,
                'amount': r.amount.plainAmountString,
                'dayOfMonth': r.dayOfMonth,
                'note': r.note,
                'vehicleId': r.vehicleId,
                'enabled': r.enabled,
                'lastAppliedMonth': r.lastAppliedMonth,
                'createdAt': r.createdAt.toUtc().toIso8601String(),
              })
          .toList(),
      'fundPlans': fundPlans
          .map((p) => <String, dynamic>{
                'id': p.id,
                'fundCode': p.fundCode,
                'fundName': p.fundName,
                'amount': p.amount.plainAmountString,
                'frequency': p.frequency.rawValue,
                'dayOfMonth': p.dayOfMonth,
                'weekday': p.weekday,
                'enabled': p.enabled,
                'nextRunDate': p.nextRunDate.toUtc().toIso8601String(),
                'lastRunDate': p.lastRunDate?.toUtc().toIso8601String(),
                'history': p.history
                    .map((run) => <String, dynamic>{
                          'id': run.id,
                          'planId': run.planId,
                          'date': run.date.toUtc().toIso8601String(),
                          'amount': run.amount.plainAmountString,
                          'note': run.note,
                        })
                    .toList(),
                'createdAt': p.createdAt.toUtc().toIso8601String(),
              })
          .toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(document);
  }

  /// 写入临时目录，供系统分享面板使用（用户可在面板里选择保存到文件/网盘/发送）。
  Future<File> writeTemp(String fileName, String content) async {
    final directory = await getTemporaryDirectory();
    final folder = Directory('${directory.path}/exports');
    if (!folder.existsSync()) folder.createSync(recursive: true);
    final file = File('${folder.path}/$fileName');
    await file.writeAsString(content, encoding: utf8);
    return file;
  }

  Future<void> shareFile(
    File file, {
    String? subject,
    String? text,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path)],
        subject: subject,
        text: text,
      ),
    );
  }

  // MARK: - 导入

  /// 自动识别格式：原版 export JSON、本应用 assets.json，或带 `# 费用记录` 段的 CSV。
  ImportOutcome importFromText(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('文件内容为空');
    }
    if (trimmed.startsWith('{')) {
      return _importJson(jsonDecode(trimmed) as Map<String, dynamic>);
    }
    return _importCsv(trimmed);
  }

  ImportOutcome _importJson(Map<String, dynamic> data) {
    var securities = 0;
    var vehicles = 0;
    var expenses = 0;
    var cashAccounts = 0;
    var recurringRules = 0;
    var fundPlans = 0;
    var skipped = 0;

    final existingSecurityIds = repository.fetchSecurities().map((e) => e.id).toSet();
    final existingVehicleIds = repository.fetchVehicles().map((e) => e.id).toSet();
    final existingExpenseIds = repository.fetchExpenses().map((e) => e.id).toSet();
    final existingCashIds =
        repository.fetchCashAccounts().map((e) => e.id).toSet();
    final existingRuleIds = repository.fetchRules().map((e) => e.id).toSet();
    final existingPlanIds = repository.fetchPlans().map((e) => e.id).toSet();

    final vehicleList = (data['vehicles'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    for (final json in vehicleList) {
      final vehicle = _vehicleFromJson(json);
      if (vehicle == null) {
        skipped += 1;
        continue;
      }
      if (existingVehicleIds.contains(vehicle.id)) {
        skipped += 1;
        continue;
      }
      repository.saveVehicle(vehicle);
      existingVehicleIds.add(vehicle.id);
      vehicles += 1;
    }

    final securityList = (data['securities'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    for (final json in securityList) {
      final security = _securityFromJson(json);
      if (security == null) {
        skipped += 1;
        continue;
      }
      if (existingSecurityIds.contains(security.id)) {
        skipped += 1;
        continue;
      }
      repository.saveSecurity(security);
      existingSecurityIds.add(security.id);
      securities += 1;
    }

    final cashList = (data['cashAccounts'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    for (final json in cashList) {
      final account = _cashFromJson(json);
      if (account == null) {
        skipped += 1;
        continue;
      }
      if (existingCashIds.contains(account.id)) {
        skipped += 1;
        continue;
      }
      repository.saveCashAccount(account);
      existingCashIds.add(account.id);
      cashAccounts += 1;
    }

    final expenseList = (data['expenses'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    for (final json in expenseList) {
      final expense = _expenseFromJson(json);
      if (expense == null) {
        skipped += 1;
        continue;
      }
      if (existingExpenseIds.contains(expense.id)) {
        skipped += 1;
        continue;
      }
      repository.saveExpense(expense);
      existingExpenseIds.add(expense.id);
      expenses += 1;
    }

    final ruleList = (data['recurringRules'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    for (final json in ruleList) {
      final rule = _ruleFromJson(json);
      if (rule == null || existingRuleIds.contains(rule.id)) {
        skipped += 1;
        continue;
      }
      repository.saveRule(rule);
      existingRuleIds.add(rule.id);
      recurringRules += 1;
    }

    final planList = (data['fundPlans'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    for (final json in planList) {
      final plan = _planFromJson(json);
      if (plan == null || existingPlanIds.contains(plan.id)) {
        skipped += 1;
        continue;
      }
      repository.savePlan(plan);
      existingPlanIds.add(plan.id);
      fundPlans += 1;
    }

    repository.persist();
    return ImportOutcome(
      securities: securities,
      vehicles: vehicles,
      expenses: expenses,
      cashAccounts: cashAccounts,
      recurringRules: recurringRules,
      fundPlans: fundPlans,
      skipped: skipped,
    );
  }

  /// 解析原版三段式 CSV；按表头定位列，不依赖列序。
  ImportOutcome _importCsv(String raw) {
    var securities = 0;
    var vehicles = 0;
    var expenses = 0;
    var skipped = 0;

    final existingSecurityIds = repository.fetchSecurities().map((e) => e.id).toSet();
    final existingVehicleIds = repository.fetchVehicles().map((e) => e.id).toSet();
    final existingExpenseIds = repository.fetchExpenses().map((e) => e.id).toSet();

    String section = '';
    List<String> header = const [];
    for (final line in const LineSplitter().convert(raw)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#')) {
        section = trimmed.replaceFirst('#', '').trim();
        header = const [];
        continue;
      }
      final cells = _splitCsvLine(trimmed);
      if (header.isEmpty) {
        header = cells;
        continue;
      }
      final row = <String, String>{};
      for (var i = 0; i < header.length && i < cells.length; i++) {
        row[header[i]] = cells[i];
      }
      switch (section) {
        case '证券持仓':
          final security = _securityFromRow(row);
          if (security == null || existingSecurityIds.contains(security.id)) {
            skipped += 1;
          } else {
            repository.saveSecurity(security);
            existingSecurityIds.add(security.id);
            securities += 1;
          }
        case '车辆资产':
          final vehicle = _vehicleFromRow(row);
          if (vehicle == null || existingVehicleIds.contains(vehicle.id)) {
            skipped += 1;
          } else {
            repository.saveVehicle(vehicle);
            existingVehicleIds.add(vehicle.id);
            vehicles += 1;
          }
        case '费用记录':
          final expense = _expenseFromRow(row);
          if (expense == null || existingExpenseIds.contains(expense.id)) {
            skipped += 1;
          } else {
            repository.saveExpense(expense);
            existingExpenseIds.add(expense.id);
            expenses += 1;
          }
        default:
          skipped += 1;
      }
    }

    repository.persist();
    return ImportOutcome(
      securities: securities,
      vehicles: vehicles,
      expenses: expenses,
      skipped: skipped,
    );
  }

  // MARK: - 字段解析

  Vehicle? _vehicleFromJson(Map<String, dynamic> j) {
    final id = _string(j['id']);
    final model = _string(j['model']);
    final plate = _string(j['plateNumber']);
    final purchasePrice = _dec(j['purchasePrice']);
    final valuation = _dec(j['currentValuation']);
    final purchaseDate = _date(j['purchaseDate']);
    if (id == null ||
        model == null ||
        plate == null ||
        purchasePrice == null ||
        valuation == null ||
        purchaseDate == null) {
      return null;
    }
    return Vehicle(
      id: id,
      model: model,
      plateNumber: plate,
      purchasePrice: purchasePrice,
      currentValuation: valuation,
      purchaseDate: purchaseDate,
      note: _string(j['note']) ?? '',
    );
  }

  Security? _securityFromJson(Map<String, dynamic> j) {
    final id = _string(j['id']);
    final name = _string(j['name']);
    final code = _string(j['code']);
    final quantity = _dec(j['quantity']);
    final costPrice = _dec(j['costPrice']);
    final currentPrice = _dec(j['currentPrice']);
    if (id == null ||
        name == null ||
        code == null ||
        quantity == null ||
        costPrice == null ||
        currentPrice == null ||
        !currentPrice.isPositive) {
      return null;
    }
    return Security(
      id: id,
      type: SecurityTypeX.fromRaw(_string(j['type']) ?? 'stock'),
      name: name,
      code: code,
      quantity: quantity,
      costPrice: costPrice,
      currentPrice: currentPrice,
      updatedAt: _date(j['updatedAt']) ?? DateTime.now(),
    );
  }

  Expense? _expenseFromJson(Map<String, dynamic> j) {
    final id = _string(j['id']);
    final amount = _dec(j['amount']);
    final occurredAt = _date(j['occurredAt']);
    if (id == null || amount == null || occurredAt == null || !amount.isPositive) {
      return null;
    }
    return Expense(
      id: id,
      type: _expenseType(_string(j['type'])),
      amount: amount,
      occurredAt: occurredAt,
      note: _string(j['note']) ?? '',
      source: ExpenseSourceX.fromRaw(_string(j['source'])),
      relatedAssetId: _string(j['relatedAssetId']),
      vehicleId: _string(j['vehicleId']),
      createdAt: _date(j['createdAt']) ?? occurredAt,
    );
  }

  CashAccount? _cashFromJson(Map<String, dynamic> j) {
    final id = _string(j['id']);
    final name = _string(j['name']);
    final balance = _dec(j['balance']);
    if (id == null || name == null || balance == null) return null;
    return CashAccount(
      id: id,
      name: name,
      balance: balance,
      updatedAt: _date(j['updatedAt']) ?? DateTime.now(),
    );
  }

  Security? _securityFromRow(Map<String, String> row) {
    final id = row['id'];
    final name = row['name'];
    final code = row['code'];
    final quantity = _dec(row['quantity']);
    final costPrice = _dec(row['costPrice']);
    final currentPrice = _dec(row['currentPrice']);
    if (id == null ||
        name == null ||
        code == null ||
        quantity == null ||
        costPrice == null ||
        currentPrice == null ||
        !currentPrice.isPositive) {
      return null;
    }
    return Security(
      id: id,
      type: SecurityTypeX.fromRaw(row['type'] ?? 'stock'),
      name: name,
      code: code,
      quantity: quantity,
      costPrice: costPrice,
      currentPrice: currentPrice,
      updatedAt: _date(row['updatedAt']) ?? DateTime.now(),
    );
  }

  Vehicle? _vehicleFromRow(Map<String, String> row) {
    final id = row['id'];
    final model = row['model'];
    final plate = row['plateNumber'];
    final purchasePrice = _dec(row['purchasePrice']);
    final valuation = _dec(row['currentValuation']);
    final purchaseDate = _date(row['purchaseDate']);
    if (id == null ||
        model == null ||
        plate == null ||
        purchasePrice == null ||
        valuation == null ||
        purchaseDate == null) {
      return null;
    }
    return Vehicle(
      id: id,
      model: model,
      plateNumber: plate,
      purchasePrice: purchasePrice,
      currentValuation: valuation,
      purchaseDate: purchaseDate,
      note: row['note'] ?? '',
    );
  }

  Expense? _expenseFromRow(Map<String, String> row) {
    final id = row['id'];
    final amount = _dec(row['amount']);
    final occurredAt = _date(row['occurredAt']);
    if (id == null || amount == null || occurredAt == null || !amount.isPositive) {
      return null;
    }
    return Expense(
      id: id,
      type: _expenseType(row['type']),
      amount: amount,
      occurredAt: occurredAt,
      note: row['note'] ?? '',
      source: ExpenseSourceX.fromRaw(row['source']),
      relatedAssetId: _nullIfEmpty(row['relatedAssetId']),
      vehicleId: _nullIfEmpty(row['vehicleId']),
      createdAt: _date(row['createdAt']) ?? occurredAt,
    );
  }

  /// 兼容 JSON 数字与字符串两种金额编码。
  static Dec? _dec(Object? value) {
    if (value == null) return null;
    if (value is num) return Dec.parse(value.toString());
    if (value is String && value.trim().isNotEmpty) return Dec.parse(value);
    return null;
  }

  static DateTime? _date(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim())?.toLocal();
  }

  static String? _string(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String? _nullIfEmpty(String? value) =>
      (value == null || value.isEmpty) ? null : value;

  static RecurringRule? _ruleFromJson(Map<String, dynamic> j) {
    final id = _string(j['id']);
    final title = _string(j['title']);
    final amount = _dec(j['amount']);
    if (id == null || title == null || amount == null || !amount.isPositive) {
      return null;
    }
    return RecurringRule(
      id: id,
      title: title,
      type: ExpenseTypeX.fromRaw(_string(j['type'])),
      amount: amount,
      dayOfMonth: ((j['dayOfMonth'] as num?)?.toInt().clamp(1, 31) ?? 1)
          .toInt(),
      note: _string(j['note']) ?? '',
      vehicleId: _string(j['vehicleId']),
      enabled: j['enabled'] as bool? ?? true,
      lastAppliedMonth: _string(j['lastAppliedMonth']),
      createdAt: _date(j['createdAt']) ?? DateTime.now(),
    );
  }

  static FundPlan? _planFromJson(Map<String, dynamic> j) {
    final id = _string(j['id']);
    final code = _string(j['fundCode']);
    final name = _string(j['fundName']);
    final amount = _dec(j['amount']);
    final nextRunDate = _date(j['nextRunDate']);
    if (id == null ||
        code == null ||
        !RegExp(r'^\d{6}$').hasMatch(code) ||
        name == null ||
        amount == null ||
        !amount.isPositive ||
        nextRunDate == null) {
      return null;
    }
    final history = (j['history'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (run) => FundPlanRun(
            id: _string(run['id']) ?? '',
            planId: id,
            date: _date(run['date']) ?? nextRunDate,
            amount: _dec(run['amount']) ?? Dec.zero,
            note: _string(run['note']) ?? '',
          ),
        )
        .where((run) => run.id.isNotEmpty)
        .toList();
    return FundPlan(
      id: id,
      fundCode: code,
      fundName: name,
      amount: amount,
      frequency: FundPlanFrequencyX.fromRaw(_string(j['frequency'])),
      dayOfMonth: ((j['dayOfMonth'] as num?)?.toInt().clamp(1, 31) ?? 1)
          .toInt(),
      weekday: ((j['weekday'] as num?)?.toInt().clamp(1, 7) ?? 1).toInt(),
      enabled: j['enabled'] as bool? ?? true,
      nextRunDate: nextRunDate,
      lastRunDate: _date(j['lastRunDate']),
      history: history,
      createdAt: _date(j['createdAt']) ?? DateTime.now(),
    );
  }

  static ExpenseType _expenseType(String? raw) => ExpenseTypeX.fromRaw(raw);

  static Vehicle? _vehicleById(List<Vehicle> vehicles, String? id) {
    if (id == null) return null;
    for (final vehicle in vehicles) {
      if (vehicle.id == id) return vehicle;
    }
    return null;
  }

  static String _cell(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// 支持带引号字段（引号内可含逗号）。
  static List<String> _splitCsvLine(String line) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i += 1;
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(char);
        }
      } else if (char == '"') {
        inQuotes = true;
      } else if (char == ',') {
        cells.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    cells.add(buffer.toString());
    return cells;
  }
}
