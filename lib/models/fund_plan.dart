import '../core/decimal.dart';

enum FundPlanFrequency { monthly, weekly }

extension FundPlanFrequencyX on FundPlanFrequency {
  String get rawValue => this == FundPlanFrequency.monthly ? 'monthly' : 'weekly';
  String get displayName => this == FundPlanFrequency.monthly ? '每月' : '每周';

  static FundPlanFrequency fromRaw(String? raw) =>
      raw == 'weekly' ? FundPlanFrequency.weekly : FundPlanFrequency.monthly;
}

/// 一次定投扣款执行记录。
class FundPlanRun {
  FundPlanRun({
    required this.id,
    required this.planId,
    required this.date,
    required this.amount,
    this.note = '',
  });

  final String id;
  final String planId;
  final DateTime date;
  final Dec amount;
  final String note;
}

/// 基金定投计划：支持每月/每周、暂停恢复、下次扣款日与历史记录。
class FundPlan {
  FundPlan({
    required this.id,
    required this.fundCode,
    required this.fundName,
    required this.amount,
    required this.frequency,
    required this.nextRunDate,
    this.dayOfMonth = 1,
    this.weekday = 1,
    this.enabled = true,
    this.lastRunDate,
    final List<FundPlanRun>? history,
    DateTime? createdAt,
  })  : history = List.unmodifiable(history ?? const <FundPlanRun>[]),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String fundCode;
  final String fundName;
  final Dec amount;
  final FundPlanFrequency frequency;
  final int dayOfMonth;
  final int weekday;
  final bool enabled;
  final DateTime nextRunDate;
  final DateTime? lastRunDate;
  final List<FundPlanRun> history;
  final DateTime createdAt;

  String get scheduleLabel => frequency == FundPlanFrequency.monthly
      ? '每月 $dayOfMonth 日'
      : '每周 ${_weekdayName(weekday)}';

  static String _weekdayName(int weekday) => switch (weekday) {
        1 => '一',
        2 => '二',
        3 => '三',
        4 => '四',
        5 => '五',
        6 => '六',
        _ => '日',
      };

  FundPlan copyWith({
    String? fundCode,
    String? fundName,
    Dec? amount,
    FundPlanFrequency? frequency,
    int? dayOfMonth,
    int? weekday,
    bool? enabled,
    DateTime? nextRunDate,
    DateTime? lastRunDate,
    List<FundPlanRun>? history,
    bool clearLastRun = false,
  }) =>
      FundPlan(
        id: id,
        fundCode: fundCode ?? this.fundCode,
        fundName: fundName ?? this.fundName,
        amount: amount ?? this.amount,
        frequency: frequency ?? this.frequency,
        dayOfMonth: dayOfMonth ?? this.dayOfMonth,
        weekday: weekday ?? this.weekday,
        enabled: enabled ?? this.enabled,
        nextRunDate: nextRunDate ?? this.nextRunDate,
        lastRunDate: clearLastRun ? null : lastRunDate ?? this.lastRunDate,
        history: history ?? this.history,
        createdAt: createdAt,
      );
}
