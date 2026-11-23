import '../core/decimal.dart';
import 'enums.dart';

/// 每月固定收支规则。
///
/// [dayOfMonth] 为期望入账日；遇小月自动取当月最后一天。
/// [lastAppliedMonth] 用 yyyy-MM 记录已执行月份，保证同月只入账一次。
class RecurringRule {
  RecurringRule({
    required this.id,
    required this.title,
    required this.type,
    required this.amount,
    required this.dayOfMonth,
    this.note = '',
    this.vehicleId,
    this.enabled = true,
    this.lastAppliedMonth,
    DateTime? createdAt,
  })  : assert(dayOfMonth >= 1 && dayOfMonth <= 31),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final ExpenseType type;
  final Dec amount;
  final int dayOfMonth;
  final String note;
  final String? vehicleId;
  final bool enabled;
  final String? lastAppliedMonth;
  final DateTime createdAt;

  bool get isIncome => type.isIncome;
  bool get isVehicle => type.isVehicle;

  RecurringRule copyWith({
    String? title,
    ExpenseType? type,
    Dec? amount,
    int? dayOfMonth,
    String? note,
    String? vehicleId,
    bool? enabled,
    String? lastAppliedMonth,
    bool clearVehicle = false,
    bool clearLastApplied = false,
  }) =>
      RecurringRule(
        id: id,
        title: title ?? this.title,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        dayOfMonth: dayOfMonth ?? this.dayOfMonth,
        note: note ?? this.note,
        vehicleId: clearVehicle ? null : vehicleId ?? this.vehicleId,
        enabled: enabled ?? this.enabled,
        lastAppliedMonth: clearLastApplied
            ? null
            : lastAppliedMonth ?? this.lastAppliedMonth,
        createdAt: createdAt,
      );
}
