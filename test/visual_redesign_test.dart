import 'package:flutter_test/flutter_test.dart';
import 'package:ios_asset_manager_flutter/app_shell.dart';
import 'package:ios_asset_manager_flutter/core/app_motion.dart';
import 'package:ios_asset_manager_flutter/core/app_state.dart';
import 'package:ios_asset_manager_flutter/core/decimal.dart';
import 'package:ios_asset_manager_flutter/core/theme.dart';
import 'package:ios_asset_manager_flutter/features/overview/overview_view.dart';
import 'package:ios_asset_manager_flutter/models/enums.dart';
import 'package:ios_asset_manager_flutter/repositories/app_repository.dart';
import 'package:ios_asset_manager_flutter/widgets/app_surfaces.dart';
import 'package:ios_asset_manager_flutter/widgets/asset_ring.dart';
import 'package:material_ui/material_ui.dart';

/// 视觉改造回归测试：主题令牌、动效降级、环形图、关键页面在手机尺寸下的稳定性。
void main() {
  test('主题集中定义色彩、卡片圆角与页面转场', () {
    final theme = AppTheme.light();
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.scaffoldBackgroundColor, Colors.transparent);
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.android],
      isA<AppPageTransition>(),
    );
    final shape = theme.cardTheme.shape as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.all(Radius.circular(22)));
    expect(AppTheme.profitColor(1), AppColors.profit);
    expect(AppTheme.profitColor(-1), AppColors.loss);
  });

  testWidgets('开启减少动态效果时入场动画直接显示终态', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: const MaterialApp(
          home: Scaffold(
            body: StaggerEntrance(index: 5, child: Text('立即显示')),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('立即显示'), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder), findsNothing);
  });

  testWidgets('金额文本动画结束后与业务数据完全一致', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedCurrencyText(value: Dec.parse('1234.5')!),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('¥1,234.50'), findsOneWidget);
  });

  testWidgets('资产环形图渲染并保持可访问语义', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetRing(
            segments: const <AssetRingSegment>[
              AssetRingSegment(label: '股票', value: 60, color: AppColors.stock),
              AssetRingSegment(label: '基金', value: 40, color: AppColors.fund),
            ],
            size: 180,
            strokeWidth: 22,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('asset-donut')), findsOneWidget);
    expect(find.byType(Semantics), findsWidgets);
  });

  testWidgets('一加 9 Pro 逻辑尺寸下总览关键元素齐全且无溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 919));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: OverviewView(state: AppState(InMemoryAppRepository())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('资产总览'), findsOneWidget);
    expect(find.byKey(const ValueKey('total-assets-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('asset-donut')), findsOneWidget);
    for (final category in AssetCategory.values) {
      expect(
        find.byKey(ValueKey('category-${category.rawValue}')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('主壳五个标签切换后页面转场不抛异常', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 919));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      AssetApp(state: AppState(InMemoryAppRepository())),
    );
    await tester.pumpAndSettle();
    expect(find.text('资产总览'), findsOneWidget);

    for (final label in <String>['记账', '证券', '车辆', '设置', '总览']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
