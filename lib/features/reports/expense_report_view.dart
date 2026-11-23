import 'package:material_ui/material_ui.dart';

import '../../core/app_motion.dart';
import '../../core/app_state.dart';
import '../../core/date_format.dart';
import '../../core/decimal.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/enums.dart';
import '../../models/expense.dart';
import '../../widgets/app_surfaces.dart';

/// 费用报表页：按月统计、类型分布、近 6 个月趋势。
/// 只读取状态；图表与增长动画不改变任何统计口径。
class ExpenseReportView extends StatelessWidget {
  const ExpenseReportView({super.key, required this.state});

  final AppState state;

  static Color _colorForType(ExpenseType type) =>
      AppColors.expenseTypeColor(type);

  static List<MapEntry<String, Dec>> _groupByMonth(
    List<Expense> expenses, {
    bool incomeOnly = false,
  }) {
    final totals = <String, Dec>{};
    for (final expense in expenses) {
      if (incomeOnly ? !expense.isIncome : expense.isIncome) continue;
      final key = AppDateFormat.month(expense.occurredAt);
      totals[key] = (totals[key] ?? Dec.zero) + expense.amount;
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return entries;
  }

  static List<_MonthTotal> _lastSixMonths(List<Expense> expenses) {
    final now = DateTime.now();
    final result = <_MonthTotal>[];
    for (var offset = 5; offset >= 0; offset--) {
      final month = DateTime(now.year, now.month - offset, 1);
      var total = Dec.zero;
      for (final expense in expenses) {
        if (expense.isIncome || expense.type == ExpenseType.investment) {
          continue;
        }
        if (expense.occurredAt.year == month.year &&
            expense.occurredAt.month == month.month) {
          total = total + expense.amount;
        }
      }
      result.add(_MonthTotal(month.year, month.month, total));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final monthly = _groupByMonth(state.expenses);
    final incomeMonthly = _groupByMonth(state.expenses, incomeOnly: true);
    final typeTotals = <ExpenseType, Dec>{
      for (final type in ExpenseType.values)
        type: state.expenses.fold<Dec>(
          Dec.zero,
          (sum, expense) => expense.type == type ? sum + expense.amount : sum,
        ),
    };
    final total = state.totalExpense;
    final trend = _lastSixMonths(state.expenses);
    final totalMicros = total.micros.toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('费用报表')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Responsive.contentMaxWidthOf(context),
                ),
                child: ListView(
                  key: const ValueKey('report-list'),
                  padding: const EdgeInsets.only(bottom: 24),
                  children: <Widget>[
                    StaggerEntrance(
                      index: 0,
                      child: _OverviewCard(
                        total: total,
                        income: state.totalIncome,
                        investment: state.totalInvestment,
                        count: state.expenses.length,
                      ),
                    ),
                    StaggerEntrance(
                      index: 1,
                      child: const SectionHeader(
                        title: '按月统计',
                        subtitle: '支出与收入分别汇总',
                      ),
                    ),
                    StaggerEntrance(
                      index: 1,
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: monthly.isEmpty && incomeMonthly.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 18),
                                child: Text('暂无收支数据'),
                              )
                            : Column(
                                children: <Widget>[
                                  for (var i = 0; i < monthly.length; i++)
                                    _MonthRow(
                                      label: monthly[i].key,
                                      amount: monthly[i].value,
                                      index: i,
                                    ),
                                  if (incomeMonthly.isNotEmpty)
                                    const Padding(
                                      padding:
                                          EdgeInsets.fromLTRB(4, 8, 4, 4),
                                      child: Divider(),
                                    ),
                                  for (var i = 0; i < incomeMonthly.length; i++)
                                    _IncomeMonthRow(
                                      label: incomeMonthly[i].key,
                                      amount: incomeMonthly[i].value,
                                      index: i,
                                    ),
                                ],
                              ),
                      ),
                    ),
                    const SectionHeader(title: '类型分布', subtitle: '各类收支占总支出比例'),
                    StaggerEntrance(
                      index: 2,
                      child: AppCard(
                        child: Column(
                          children: ExpenseType.values
                              .where(
                                (type) =>
                                    (typeTotals[type]?.micros ?? 0) > 0,
                              )
                              .map(
                                (type) => _TypeBarRow(
                                  label:
                                      '${type.group.displayName} · ${type.displayName}',
                                  amount: typeTotals[type] ?? Dec.zero,
                                  fraction: totalMicros <= 0
                                      ? 0
                                      : (typeTotals[type]?.micros ?? 0) /
                                          totalMicros,
                                  color: _colorForType(type),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                    const SectionHeader(title: '近 6 个月趋势', subtitle: '每月支出走势'),
                    StaggerEntrance(
                      index: 3,
                      child: AppCard(
                        child: _TrendChart(months: trend),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.total,
    required this.income,
    required this.investment,
    required this.count,
  });

  final Dec total;
  final Dec income;
  final Dec investment;
  final int count;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.fromLTRB(
        Responsive.gutterOf(context),
        12,
        Responsive.gutterOf(context),
        4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.vehicle.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.payments_outlined,
                              size: 16, color: AppColors.vehicle),
                        ),
                        const SizedBox(width: 8),
                        Text('总支出',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AnimatedCurrencyText(
                      key: const ValueKey('report-total'),
                      value: total,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text('记录笔数', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 10),
                  AnimatedCountText(
                    value: count,
                    builder: (value) => Text(
                      '$value 笔',
                      key: const ValueKey('report-count'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('收入合计',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        income.currencyString,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.mint),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text('定投合计',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        investment.currencyString,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.label,
    required this.amount,
    required this.index,
  });

  final String label;
  final Dec amount;
  final int index;

  @override
  Widget build(BuildContext context) {
    return StaggerEntrance(
      index: index,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_month,
                  size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Text(label, key: ValueKey('report-month-$label')),
            const Spacer(),
            Text(
              amount.currencyString,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomeMonthRow extends StatelessWidget {
  const _IncomeMonthRow({
    required this.label,
    required this.amount,
    required this.index,
  });

  final String label;
  final Dec amount;
  final int index;

  @override
  Widget build(BuildContext context) {
    return StaggerEntrance(
      index: index,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.mintSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_downward,
                  size: 16, color: AppColors.mint),
            ),
            const SizedBox(width: 12),
            Text(label, key: ValueKey('report-income-month-$label')),
            const Spacer(),
            Text(
              amount.currencyString,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: AppColors.mint),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个类型的横向占比条：数据变化时平滑伸长。
class _TypeBarRow extends StatelessWidget {
  const _TypeBarRow({
    required this.label,
    required this.amount,
    required this.fraction,
    required this.color,
  });

  final String label;
  final Dec amount;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          Flexible(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: TweenAnimationBuilder<double>(
              duration: AppMotion.durationOf(context, AppMotion.data),
              curve: AppMotion.entrance,
              tween: Tween<double>(begin: 0, end: fraction.clamp(0.0, 1.0)),
              builder: (context, value, _) => SizedBox(
                height: 10,
                child: CustomPaint(
                  key: ValueKey('report-type-bar-$label'),
                  painter: _FractionBarPainter(fraction: value, color: color),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.track,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                amount.currencyString,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FractionBarPainter extends CustomPainter {
  const _FractionBarPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final width = fraction.clamp(0.0, 1.0) * size.width;
    if (width <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, size.height),
        const Radius.circular(5),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_FractionBarPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color;
}

class _MonthTotal {
  const _MonthTotal(this.year, this.month, this.amount);

  final int year;
  final int month;
  final Dec amount;
}

/// 近 6 个月趋势柱状图：柱高随动画从基线生长。
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.months});

  final List<_MonthTotal> months;

  @override
  Widget build(BuildContext context) {
    final maxMicros = months.fold<double>(
      0,
      (max, item) =>
          item.amount.micros > max ? item.amount.micros.toDouble() : max,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TweenAnimationBuilder<double>(
          duration: AppMotion.durationOf(context, AppMotion.data),
          curve: AppMotion.entrance,
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, progress, _) => SizedBox(
            key: const ValueKey('report-trend-chart'),
            height: Responsive.chartHeightOf(context),
            child: CustomPaint(
              painter: _TrendPainter(
                months: months,
                maxMicros: maxMicros,
                progress: progress,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: months
              .map(
                (item) => Expanded(
                  child: Text(
                    '${item.month}月',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.months,
    required this.maxMicros,
    required this.progress,
  });

  final List<_MonthTotal> months;
  final double maxMicros;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height - 1;
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      Paint()
        ..color = AppColors.outlineSoft
        ..strokeWidth = 1,
    );

    if (months.isEmpty || maxMicros <= 0) return;
    final slot = size.width / months.length;
    final barWidth = slot * 0.48;
    final usableHeight = size.height - 16;

    for (var index = 0; index < months.length; index++) {
      final value = months[index].amount.micros.toDouble();
      final ratio = (value / maxMicros).clamp(0.0, 1.0);
      final height = ratio * usableHeight * progress;
      if (height <= 0) continue;
      final left = slot * index + (slot - barWidth) / 2;
      final bar = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, baseline - height, barWidth, height),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        bar,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[AppColors.primary, AppColors.violet],
          ).createShader(bar.outerRect),
      );
    }
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) =>
      oldDelegate.maxMicros != maxMicros ||
      oldDelegate.months != months ||
      oldDelegate.progress != progress;
}
