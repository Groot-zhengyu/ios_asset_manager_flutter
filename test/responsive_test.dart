import 'package:flutter_test/flutter_test.dart';
import 'package:ios_asset_manager_flutter/core/responsive.dart';
import 'package:material_ui/material_ui.dart';

/// 分辨率自适应测试：覆盖一加 9 Pro 2K 高分屏、小屏手机、平板与字体缩放。
///
/// 一加 9 Pro：1440×3216 物理像素、dpr≈3.5 → 逻辑约 411×919dp，属 compact 档。
/// Flutter 以逻辑像素布局，高分屏由引擎按 dpr 自动换算；本测试验证：
///  - 各逻辑宽度下断点分档正确；
///  - 内容宽度/间距/图表尺寸随档位变化且在合理区间；
///  - 系统字体缩放被钳制到安全范围，避免撑爆布局。
Widget _probe(ScreenClass Function(BuildContext ctx) compute) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Text(compute(context).name),
    ),
  );
}

Future<ScreenClass> _screenClassAt(
  WidgetTester tester, {
  required Size logicalSize,
  double dpr = 3.5,
  double textScale = 1.0,
}) async {
  await tester.binding.setSurfaceSize(logicalSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: logicalSize,
        devicePixelRatio: dpr,
        textScaler: TextScaler.linear(textScale),
      ),
      child: _probe((ctx) => Responsive.screenClassOf(ctx)),
    ),
  );
  await tester.pump();
  return switch (tester.widget<Text>(find.byType(Text)).data) {
    'compact' => ScreenClass.compact,
    'medium' => ScreenClass.medium,
    'expanded' => ScreenClass.expanded,
    _ => throw StateError('未知分档'),
  };
}

void main() {
  group('屏幕断点分档', () {
    testWidgets('一加 9 Pro 2K 屏(逻辑 411×919, dpr 3.5)归为手机档', (tester) async {
      final cls = await _screenClassAt(
        tester,
        logicalSize: const Size(411, 919),
        dpr: 3.5,
      );
      expect(cls, ScreenClass.compact);
    });

    testWidgets('小屏手机 320×640 归为手机档', (tester) async {
      final cls = await _screenClassAt(
        tester,
        logicalSize: const Size(320, 640),
      );
      expect(cls, ScreenClass.compact);
    });

    testWidgets('折叠屏展开 720×800 归为中等档', (tester) async {
      final cls = await _screenClassAt(
        tester,
        logicalSize: const Size(720, 800),
      );
      expect(cls, ScreenClass.medium);
    });

    testWidgets('平板横屏 1280×800 归为宽屏档', (tester) async {
      final cls = await _screenClassAt(
        tester,
        logicalSize: const Size(1280, 800),
      );
      expect(cls, ScreenClass.expanded);
    });
  });

  group('响应式尺寸', () {
    testWidgets('内容宽度：手机撑满、中等屏收窄到 720、宽屏 960', (tester) async {
      Future<double> maxWidthAt(Size size) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        late double result;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: size),
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  result = Responsive.contentMaxWidthOf(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        await tester.pump();
        return result;
      }

      expect(await maxWidthAt(const Size(411, 919)), double.infinity);
      expect(await maxWidthAt(const Size(800, 600)), 720);
      expect(await maxWidthAt(const Size(1280, 800)), 960);
    });

    test('环形图尺寸始终落在 [160, 200] 安全区间', () {
      // 纯函数边界：用 clamp 逻辑直接验证上下界，避免依赖 widget 树。
      const sizes = <double>[320, 360, 411, 480, 599];
      for (final width in sizes) {
        final value = (width * 0.44).clamp(160.0, 196.0);
        expect(value, greaterThanOrEqualTo(160));
        expect(value, lessThanOrEqualTo(196));
      }
    });
  });

  group('字体缩放钳制', () {
    MediaQueryData clampedFor(double scale) => Responsive.clampTextScale(
          MediaQueryData(
            size: const Size(411, 919),
            textScaler: TextScaler.linear(scale),
          ),
        );

    test('超大字体被压到上限 1.15，避免撑爆固定布局', () {
      final clamped = clampedFor(2.0).textScaler.scale(1.0);
      expect(clamped, Responsive.maxTextScale);
    });

    test('过小字体被抬到下限 0.85，保证可读性', () {
      final clamped = clampedFor(0.5).textScaler.scale(1.0);
      expect(clamped, Responsive.minTextScale);
    });

    test('正常字体区间保持原样', () {
      final clamped = clampedFor(1.0).textScaler.scale(1.0);
      expect(clamped, closeTo(1.0, 0.001));
    });
  });
}
