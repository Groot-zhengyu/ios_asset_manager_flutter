import '../core/decimal.dart';
import 'enums.dart';

/// 费用记录：amount 恒为正、语义为支出；费用不计入总资产，仅进入支出统计。
class Expense {
  final String id;
  final ExpenseType type;
  final Dec amount;
  final DateTime occurredAt;
  final String note;
  final ExpenseSource source;
  final String? relatedAssetId;
  final String? vehicleId;
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
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
