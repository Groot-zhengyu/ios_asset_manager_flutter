import '../core/decimal.dart';
import 'enums.dart';

/// 收支记录：amount 恒为正；语义由 [type.isIncome] 决定。
/// 费用不计入总资产，收入也不计入总资产，只进入现金流统计。
class Expense {
  final String id;
  final ExpenseType type;
  final Dec amount;
  final DateTime occurredAt;
  final String note;
  final ExpenseSource source;
  final String? relatedAssetId;
  final String? vehicleId;

  /// 生成该记录的规则/计划 id，便于后续审计与去重。
  final String? sourceId;
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.type,
    required this.amount,
    required this.occurredAt,
    this.note = '',
    this.source = ExpenseSource.manual,
    this.relatedAssetId,
    this.vehicleId,
    this.sourceId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isIncome => type.isIncome;
  bool get isVehicleExpense => type.isVehicle;

  /// 列表展示用带符号金额：收入 +，支出 -。
  String get signedCurrencyString =>
      isIncome ? '+${amount.currencyString}' : '-${amount.currencyString}';
}
