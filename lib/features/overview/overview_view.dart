import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/decimal.dart';
import '../../core/theme.dart';
import '../../models/enums.dart';
import '../../services/asset_calculator.dart';

/// 总览页：总资产/总盈亏大卡片 + 手绘资产环形图 + 分类下钻列表 + 底部快速记账。
/// 大屏通过 LayoutBuilder(maxWidth: 720) 居中，关键控件均带 ValueKey。
class OverviewView extends StatefulWidget {
  const OverviewView({
    super.key,
    required this.state,
    this.onJumpToTab,
    this.onQuickRecord,
  });

  final AppState state;
  final ValueChanged<int>? onJumpToTab;
  final VoidCallback? onQuickRecord;

  @override
  State<OverviewView> createState() => _OverviewViewState();
}

class _OverviewViewState extends State<OverviewView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _chartController;
  late final CurvedAnimation _chartAnimation;

  @override
  void initState() {
    super.initState();
    _chartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _chartAnimation = CurvedAnimation(
      parent: _chartController,
      curve: Curves.easeOut,
    );
    _chartController.forward();
  }

  @override
  void dispose() {
    _chartController.dispose();
    super.dispose();
  }

  /// 分类对应的标签页：0=总览 1=记账 2=证券 3=车辆 4=设置。
  static int _tabIndexFor(AssetCategory category) => switch (category) {
        AssetCategory.stock => 2,
        AssetCategory.fund => 2,
        AssetCategory.vehicle => 3,
        AssetCategory.cash => 1,
      };

  Widget _entrance(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 320 + index * 90),
      tween: Tween<double>(begin: 0, end: 1),
      curve: Curves.easeOut,
      child: child,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.state.snapshot;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _entrance(0, _TotalAssetsCard(snapshot: snapshot)),
                            _entrance(
                              1,
                              _CategoryDonut(
                                animation: _chartAnimation,
                                snapshot: snapshot,
                              ),
                            ),
                            _entrance(
                              2,
                              _CategoryList(
                                snapshot: snapshot,
                                onJumpToTab: widget.onJumpToTab,
                                tabIndexFor: _tabIndexFor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: FilledButton.icon(
                        key: const ValueKey('quick-record-button'),
                        onPressed: widget.onQuickRecord,
                        icon: const Icon(AppIcons.quickRecord),
                        label: const Text('快速记账'),
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

/// 顶部总资产 / 总盈亏大卡片，数字用 TweenAnimationBuilder 做过渡。
class _TotalAssetsCard extends StatelessWidget {
  const _TotalAssetsCard({required this.snapshot});

  final AssetSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('total-assets-card'),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('总资产', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            TweenAnimationBuilder<int>(
              key: const ValueKey('total-assets'),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              tween: IntTween(begin: 0, end: snapshot.totalAssets.micros),
              builder: (context, micros, child) => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  Dec.fromMicros(micros).currencyString,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Text('总盈亏', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(width: 12),
                Expanded(
                  child: TweenAnimationBuilder<int>(
                    key: const ValueKey('total-profit'),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    tween: IntTween(begin: 0, end: snapshot.totalProfit.micros),
                    builder: (context, micros, child) => FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Dec.fromMicros(micros).signedCurrencyString,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppTheme.profitColor(micros),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 一段环形图数据。
class _DonutSegment {
  const _DonutSegment(this.category, this.value, this.color);

  final AssetCategory category;
  final Dec value;
  final Color color;
}

const List<Color> _segmentColors = <Color>[
  Color(0xFFD32F2F), // 股票
  Color(0xFF1976D2), // 基金
  Color(0xFFF57C00), // 车辆
  Color(0xFF388E3C), // 现金及其他
];

List<_DonutSegment> _segmentsOf(AssetSnapshot snapshot) => <_DonutSegment>[
      _DonutSegment(
          AssetCategory.stock, snapshot.stockValue, _segmentColors[0]),
      _DonutSegment(AssetCategory.fund, snapshot.fundValue, _segmentColors[1]),
      _DonutSegment(
        AssetCategory.vehicle,
        snapshot.vehicleValue,
        _segmentColors[2],
      ),
      _DonutSegment(AssetCategory.cash, snapshot.cashValue, _segmentColors[3]),
    ];

/// 资产分类环形图：CustomPainter 手绘 + 进场动画 + 中文图例与金额。
class _CategoryDonut extends StatelessWidget {
  const _CategoryDonut({
    required this.animation,
    required this.snapshot,
  });

  final Animation<double> animation;
  final AssetSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final segments = _segmentsOf(snapshot);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('资产分布', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Center(
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, child) => SizedBox(
                  width: 180,
                  height: 180,
                  child: CustomPaint(
                    key: const ValueKey('asset-donut'),
                    painter: _DonutPainter(
                      segments: segments,
                      progress: animation.value,
                    ),
                    child: Center(
                      child: Text(
                        '总资产',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: segments
                  .map(
                    (segment) => _LegendItem(
                      key: ValueKey('legend-${segment.category.rawValue}'),
                      segment: segment,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 手绘 donut：按各分类金额占比绘制圆弧，progress 控制进场扫描。
class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.segments, required this.progress});

  final List<_DonutSegment> segments;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<int>(
      0,
      (sum, segment) => sum + segment.value.micros.abs(),
    );
    const strokeWidth = 22.0;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    if (total == 0) {
      canvas.drawCircle(
        rect.center,
        (size.width - strokeWidth) / 2,
        Paint()
          ..color = const Color(0xFFE0E0E0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
      return;
    }

    var startAngle = -math.pi / 2; // 从 12 点方向开始
    for (final segment in segments) {
      if (segment.value.micros <= 0) continue;
      final sweep = segment.value.micros / total * 2 * math.pi * progress;
      if (sweep <= 0) continue;
      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        false,
        Paint()
          ..color = segment.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.segments != segments;
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({super.key, required this.segment});

  final _DonutSegment segment;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: segment.color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${segment.category.displayName} ${segment.value.currencyString}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// 四行分类列表：图标 + 名称 + 金额 + 占比，点击跳转对应标签页。
class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.snapshot,
    required this.onJumpToTab,
    required this.tabIndexFor,
  });

  final AssetSnapshot snapshot;
  final ValueChanged<int>? onJumpToTab;
  final int Function(AssetCategory) tabIndexFor;

  static Dec _ratio(Dec value, Dec total) {
    if (total.isZero) return Dec.zero;
    return Dec.fromMicros(value.micros.abs() * 1000000 ~/ total.micros.abs());
  }

  @override
  Widget build(BuildContext context) {
    final segments = _segmentsOf(snapshot);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: segments.map((segment) {
          final ratio = _ratio(segment.value, snapshot.totalAssets);
          return ListTile(
            key: ValueKey('category-${segment.category.rawValue}'),
            leading: Icon(AppIcons.forAssetCategory(segment.category)),
            title: Text(segment.category.displayName),
            subtitle: Text('占比 ${ratio.percentString}'),
            trailing: Text(
              segment.value.currencyString,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            onTap: onJumpToTab == null
                ? null
                : () => onJumpToTab!(tabIndexFor(segment.category)),
          );
        }).toList(),
      ),
    );
  }
}
