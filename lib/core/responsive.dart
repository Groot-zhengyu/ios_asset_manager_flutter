import 'package:material_ui/material_ui.dart';

/// 屏幕宽度分档。
///
/// - [compact]：手机竖屏（< 600dp 逻辑宽度），包含一加 9 Pro（1440×3216 物理、
///   dpr≈3.5、逻辑宽约 411dp）等主流高分屏手机。
/// - [medium]：折叠屏展开 / 小平板 / 大屏手机横屏（600~1100dp）。
/// - [expanded]：平板横屏 / 桌面窗口（>= 1100dp）。
enum ScreenClass { compact, medium, expanded }

/// 响应式布局工具：集中管理断点、内容宽度、间距与自适应尺寸。
///
/// Flutter 使用逻辑像素(dp)布局，高分屏(如一加 9 Pro 的 2K 屏)由引擎按 dpr
/// 自动换算，界面不会因物理分辨率高而缩小；真正需要自适应的是：
///  1. 系统字体缩放（用 [clampTextScale] 钳制，避免超大字体撑爆固定布局）；
///  2. 不同逻辑宽度（320dp 小屏 ~ 平板/折叠屏）下的内容宽度与间距；
///  3. 固定像素图表/控件尺寸随可用宽度缩放。
class Responsive {
  const Responsive._();

  /// 进入 medium 档的逻辑宽度阈值。
  static const double compactBreakpoint = 600;

  /// 进入 expanded 档的逻辑宽度阈值。
  static const double expandedBreakpoint = 1100;

  /// 系统字体缩放钳制区间：既尊重用户偏好，又不破坏固定布局。
  static const double minTextScale = 0.85;
  static const double maxTextScale = 1.15;

  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static double heightOf(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  static ScreenClass screenClassOf(BuildContext context) {
    final width = widthOf(context);
    if (width >= expandedBreakpoint) return ScreenClass.expanded;
    if (width >= compactBreakpoint) return ScreenClass.medium;
    return ScreenClass.compact;
  }

  /// 页面内容最大宽度：手机上撑满，宽屏居中收窄，避免超宽屏拉伸变形。
  static double contentMaxWidthOf(BuildContext context) =>
      switch (screenClassOf(context)) {
        ScreenClass.compact => double.infinity,
        ScreenClass.medium => 720,
        ScreenClass.expanded => 960,
      };

  /// 页面左右安全间距（卡片外边距基准）。
  static double gutterOf(BuildContext context) =>
      switch (screenClassOf(context)) {
        ScreenClass.compact => 16,
        ScreenClass.medium => 24,
        ScreenClass.expanded => 32,
      };

  /// 卡片内部 padding：高分宽屏更舒展。
  static double cardPaddingOf(BuildContext context) =>
      switch (screenClassOf(context)) {
        ScreenClass.compact => 16,
        ScreenClass.medium => 20,
        ScreenClass.expanded => 24,
      };

  /// 环形图直径：以 180 为基准自适应，钳制在 [160, 200]。
  ///
  /// 手机档(< 600dp，含 2K 高分屏的一加 9 Pro，逻辑宽约 411dp)按屏宽小幅缩放；
  /// 宽屏档固定 180 —— 环形图位于可滚动区，宽屏下放大反而把下方列表挤出视口。
  static double donutSizeOf(BuildContext context) =>
      switch (screenClassOf(context)) {
        ScreenClass.compact => (widthOf(context) * 0.44).clamp(160.0, 196.0),
        ScreenClass.medium => 180,
        ScreenClass.expanded => 200,
      };

  /// 环形图描边宽度：随直径略缩放，保持视觉比例。
  static double donutStrokeOf(BuildContext context) =>
      donutSizeOf(context) >= 190 ? 24.0 : 22.0;

  /// 趋势柱状图高度：宽屏更舒展。
  static double chartHeightOf(BuildContext context) =>
      switch (screenClassOf(context)) {
        ScreenClass.compact => 140,
        ScreenClass.medium => 180,
        ScreenClass.expanded => 220,
      };

  /// 把系统字体缩放钳制到安全区间，返回可直接传给 MediaQuery 的数据。
  static MediaQueryData clampTextScale(MediaQueryData data) {
    final scale = data.textScaler.scale(1.0).clamp(minTextScale, maxTextScale);
    return data.copyWith(textScaler: TextScaler.linear(scale));
  }
}
