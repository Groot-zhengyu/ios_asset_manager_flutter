import '../core/decimal.dart';

/// 现金及其他：余额直接计入总资产。
class CashAccount {
  final String id;
  final String name;
  final Dec balance;
  final DateTime updatedAt;

  CashAccount({
    required this.id,
    required this.name,
    required this.balance,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();
}
