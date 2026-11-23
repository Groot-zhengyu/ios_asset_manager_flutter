import 'package:material_ui/material_ui.dart';

import '../../core/app_icons.dart';
import '../../core/app_motion.dart';
import '../../core/app_state.dart';
import '../../core/date_format.dart';
import '../../core/decimal.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/enums.dart';
import '../../services/asset_calculator.dart';
import '../../widgets/app_surfaces.dart';
import '../../widgets/asset_ring.dart';

/// 总览页：大标题 + 总资产英雄卡 + 资产分布环 + 分类下钻 + 底部快速记账。
/// 仅调整视觉与动效，取值、跳转与统计逻辑保持原样。
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

class _OverviewViewState extends State<OverviewView> {
  /// 分类对应的标签页：0=总览 1=记账 2=证券 3=车辆 4=设置。
  static int _tabIndexFor(AssetCategory category) => switch (category) {
    AssetCategory.stock => 2,
    AssetCategory.fund => 2,
    AssetCategory.vehicle => 3,
    AssetCategory.cash => 1,
  };

  Widget _entrance(int index, Widget child) =>
      StaggerEntrance(index: index, child: child);

  /// 手机竖屏纵向堆叠；折叠屏/平板把英雄卡与环形图并排，减少滚动。
  Widget _topSection(BuildContext context, AssetSnapshot snapshot) {
    final hero = _entrance(0, _HeroAssetsCard(snapshot: snapshot));
    final donut = _entrance(1, _CategoryDonut(snapshot: snapshot));
    if (Responsive.screenClassOf(context) == ScreenClass.compact) {
      return Column(children: <Widget>[hero, donut]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: 5, child: hero),
        Expanded(flex: 4, child: donut),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.state.snapshot;
    final gutter = Responsive.gutterOf(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Responsive.contentMaxWidthOf(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                          _topSection(context, snapshot),
                          _entrance(
                            2,
                              _CategoryList(
                                snapshot: snapshot,
                                onJumpToTab: widget.onJumpToTab,
                                tabIndexFor: _tabIndexFor,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 16),
                      child: PressFeedback(
                        child: FilledButton.icon(
                          key: const ValueKey('quick-record-button'),
                          onPressed: widget.onQuickRecord,
                          icon: const Icon(AppIcons.quickRecord),
                          label: const Text('快速记账'),
                        ),
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

/// 顶部英雄卡：深蓝到紫的渐变、柔光点缀与大幅数字，呼应健身 App 的首屏信息层级。
class _HeroAssetsCard extends StatelessWidget {
  const _HeroAssetsCard({required this.snapshot});

  final AssetSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final gutter = Responsive.gutterOf(context);
    final padding = Responsive.cardPaddingOf(context) + 4;
    final positive = snapshot.totalProfit.micros >= 0;
    final signColor = positive
        ? const Color(0xFFFF9A9A) // 盈利：亮红，A 股习惯
        : const Color(0xFF86EFAC); // 亏损：亮绿

    return Container(
      key: const ValueKey('total-assets-card'),
      margin: EdgeInsets.fromLTRB(gutter, 16, gutter, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.primaryDeep,
            AppColors.primary,
            AppColors.violet,
          ],
          stops: <double>[0, 0.55, 1],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -56,
            right: -28,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.24),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '资产总览',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '证券、车辆与现金，一眼看清',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.78)),
                ),
                SizedBox(height: padding + 10),
                Text(
                  '总资产',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.76)),
                ),
                const SizedBox(height: 6),
                AnimatedCurrencyText(
                  key: const ValueKey('total-assets'),
                  value: snapshot.totalAssets,
                  style: Theme.of(context).textTheme.displayMedium
                      ?.copyWith(color: Colors.white, letterSpacing: -1.4),
                ),
                const SizedBox(height: 18),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                      child: Icon(
                        positive ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 16,
                        color: signColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '总盈亏',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: Colors.white.withValues(alpha: 0.82)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedCurrencyText(
                        key: const ValueKey('total-profit'),
                        value: snapshot.totalProfit,
                        signed: true,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(color: signColor),
                        duration: AppMotion.data,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '更新于 ${AppDateFormat.dateTime(snapshot.computedAt)}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.62)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 环形图数据段：沿用原有四类资产口径。
class _DonutSegment {
  const _DonutSegment(this.category, this.value, this.color);

  final AssetCategory category;
  final Dec value;
  final Color color;
}

List<_DonutSegment> _segmentsOf(AssetSnapshot snapshot) => <_DonutSegment>[
  _DonutSegment(AssetCategory.stock, snapshot.stockValue, AppColors.stock),
  _DonutSegment(AssetCategory.fund, snapshot.fundValue, AppColors.fund),
  _DonutSegment(AssetCategory.vehicle, snapshot.vehicleValue, AppColors.vehicle),
  _DonutSegment(AssetCategory.cash, snapshot.cashValue, AppColors.cash),
];

class _CategoryDonut extends StatelessWidget {
  const _CategoryDonut({required this.snapshot});

  final AssetSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final segments = _segmentsOf(snapshot);
    final ringSegments = segments
        .map(
          (segment) => AssetRingSegment(
            label: segment.category.displayName,
            value: segment.value.micros / 1000000,
            color: segment.color,
          ),
        )
        .toList();

    return Column(
      children: <Widget>[
        SectionHeader(
          title: '资产分布',
          subtitle: '按当前估值计算占比',
        ),
        AppCard(
          child: Column(
            children: <Widget>[
              AssetRing(
                segments: ringSegments,
                size: Responsive.donutSizeOf(context),
                strokeWidth: Responsive.donutStrokeOf(context),
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${segments.length} 类资产',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '占比一览',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
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
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({super.key, required this.segment});

  final _DonutSegment segment;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: segment.color,
              borderRadius: BorderRadius.circular(4),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: segment.color.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${segment.category.displayName} ${segment.value.currencyString}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.inkSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 分类列表：占比条随数据增长，行逐条入场，点击跳转保持原逻辑。
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
    return Column(
      children: <Widget>[
        const SectionHeader(title: '资产明细', subtitle: '点击任一项查看对应模块'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: <Widget>[
              for (var i = 0; i < segments.length; i++)
                StaggerEntrance(
                  index: i,
                  child: _CategoryRow(
                    segment: segments[i],
                    ratio: _ratio(segments[i].value, snapshot.totalAssets),
                    onTap: onJumpToTab == null
                        ? null
                        : () => onJumpToTab!(tabIndexFor(segments[i].category)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.segment,
    required this.ratio,
    required this.onTap,
  });

  final _DonutSegment segment;
  final Dec ratio;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ListTile(
          key: ValueKey('category-${segment.category.rawValue}'),
          leading: CircleAvatar(
            backgroundColor: segment.color.withValues(alpha: 0.13),
            child: Icon(
              AppIcons.forAssetCategory(segment.category),
              color: segment.color,
              size: 20,
            ),
          ),
          title: Text(segment.category.displayName),
          subtitle: Text('占比 ${ratio.percentString}'),
          trailing: Text(
            segment.value.currencyString,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: AppColors.ink),
          ),
          onTap: onTap,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
          child: _RatioBar(
            fraction: ratio.micros / 1000000,
            color: segment.color,
          ),
        ),
      ],
    );
  }
}

class _RatioBar extends StatelessWidget {
  const _RatioBar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: AppMotion.durationOf(context, AppMotion.data),
      curve: AppMotion.entrance,
      tween: Tween<double>(begin: 0, end: fraction.clamp(0.0, 1.0)),
      builder: (context, value, _) => LayoutBuilder(
        builder: (context, constraints) => Container(
          height: 4,
          width: constraints.maxWidth * value,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
