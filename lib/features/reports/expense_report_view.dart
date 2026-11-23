import 'package:material_ui/material_ui.dart';

import '../../core/app_state.dart';
import '../../core/decimal.dart';
import '../../models/enums.dart';
import '../../models/expense.dart';

/// 费用报表页：按月统计、类型分布横向条形图、近 6 个月趋势柱状图。
/// 仅做读取与统计，不修改状态，因此是无状态的 StatelessWidget。
class ExpenseReportView extends StatelessWidget {
  const ExpenseReportView({super.key, required this.state});

  final AppState state;

  static Color _colorForType(ExpenseType type) => switch (type) {
        ExpenseType.fuel => const Color(0xFFE65100),
        ExpenseType.etc => const Color(0xFF1565C0),
        ExpenseType.other => const Color(0xFF757575),
      };

  static List<MapEntry<String, Dec>> _groupByMonth(List<Expense> expenses) {
    final totals = <String, Dec>{};
    for (final expense in expenses) {
      final key =
          '${expense.occurredAt.year}-${expense.occurredAt.month.toString().padLeft(2, '0')}';
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
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  key: const ValueKey('report-list'),
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    _OverviewCard(total: total, count: state.expenses.length),
                    const SizedBox(height: 16),
                    const _SectionTitle('按月统计'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: monthly.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Text('暂无费用数据'),
                              )
                            : Column(
                                children: monthly
                                    .map(
                                      (entry) => _MonthRow(
                                        label: entry.key,
                                        amount: entry.value,
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _SectionTitle('类型分布'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          children: ExpenseType.values
                              .map(
                                (type) => _TypeBarRow(
                                  label: type.displayName,
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
                    const SizedBox(height: 16),
                    const _SectionTitle('近 6 个月趋势'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: _TrendChart(months: trend),
                      ),
                    ),
                    const SizedBox(height: 24),
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
  const _OverviewCard({required this.total, required this.count});

  final Dec total;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('总支出', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  total.currencyString,
                  key: const ValueKey('report-total'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text('记录笔数', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  '$count 笔',
                  key: const ValueKey('report-count'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({required this.label, required this.amount});

  final String label;
  final Dec amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          const Icon(Icons.calendar_month, size: 18),
          const SizedBox(width: 10),
          Text(label, key: ValueKey('report-month-$label')),
          const Spacer(),
          Text(
            amount.currencyString,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// 单个类型的横向占比条：条形长度由 CustomPainter 绘制。
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          SizedBox(width: 64, child: Text(label)),
          Expanded(
            child: SizedBox(
              height: 16,
              child: CustomPaint(
                key: ValueKey('report-type-bar-$label'),
                painter: _FractionBarPainter(fraction: fraction, color: color),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 84,
            child: Text(
              amount.currencyString,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
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
    final bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, size.height),
      const Radius.circular(6),
    );
    canvas.drawRRect(bar, Paint()..color = color);
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

/// 最近 6 个月趋势柱状图：柱高按月金额比例。
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
        SizedBox(
          key: const ValueKey('report-trend-chart'),
          height: 160,
          child: CustomPaint(
            painter: _TrendPainter(months: months, maxMicros: maxMicros),
            // 无 child 时 CustomPaint 宽度为 0，必须撑满父级约束才能画出柱状图。
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 8),
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
  const _TrendPainter({required this.months, required this.maxMicros});

  final List<_MonthTotal> months;
  final double maxMicros;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height - 1;
    final axisPaint = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      axisPaint,
    );

    if (months.isEmpty || maxMicros <= 0) return;
    final slot = size.width / months.length;
    final barWidth = slot * 0.55;
    final usableHeight = size.height - 12;
    final barPaint = Paint()..color = const Color(0xFF2E6B5E);

    for (var index = 0; index < months.length; index++) {
      final value = months[index].amount.micros.toDouble();
      final ratio = (value / maxMicros).clamp(0.0, 1.0);
      final height = ratio * usableHeight;
      if (height <= 0) continue;
      final left = slot * index + (slot - barWidth) / 2;
      final bar = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, baseline - height, barWidth, height),
        const Radius.circular(4),
      );
      canvas.drawRRect(bar, barPaint);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) =>
      oldDelegate.maxMicros != maxMicros || oldDelegate.months != months;
}
