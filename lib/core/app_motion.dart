import 'package:material_ui/material_ui.dart';

/// 全应用统一的动效节奏。
///
/// 借鉴 iOS 健身类 App 的手感：入场干脆、数据变化有惯性、退场克制；
/// 所有动画均为有限时长，不使用无限循环，避免持续分散注意力。
class AppMotion {
  AppMotion._();

  /// 按压、hover 等即时反馈。
  static const Duration feedback = Duration(milliseconds: 130);

  /// 页面切换、列表入场、卡片展开等常规过渡。
  static const Duration standard = Duration(milliseconds: 280);

  /// 数据数字、图表、进度环等强调型动画。
  static const Duration data = Duration(milliseconds: 720);

  /// iOS 风格 ease-out：起步略快、末尾平滑停住。
  static const Curve entrance = Cubic(0.16, 1, 0.3, 1);

  /// 标准缓动，适合页面切换与互相穿插的淡入淡出。
  static const Curve smooth = Cubic(0.2, 0, 0, 1);

  /// 退场稍快，避免旧页面拖泥带水。
  static const Curve exit = Cubic(0.4, 0, 1, 1);

  /// 尊重系统「减少动态效果」设置。
  static bool reduceMotionOf(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// 按系统设置折算实际时长。
  static Duration durationOf(BuildContext context, Duration duration) =>
      reduceMotionOf(context) ? Duration.zero : duration;

  /// 按系统设置折算曲线。
  static Curve curveOf(BuildContext context, Curve curve) =>
      reduceMotionOf(context) ? Curves.linear : curve;
}

/// 列表/卡片的分层入场动画。
///
/// [index] 越大延迟越久，但最多只延迟 6 档，长列表不会越滑越慢；
/// 打开系统「减少动态效果」时直接显示终态。
class StaggerEntrance extends StatelessWidget {
  const StaggerEntrance({
    super.key,
    required this.index,
    required this.child,
    this.offset = const Offset(0, 0.018),
    this.scale = 0.985,
  });

  final int index;
  final Widget child;
  final Offset offset;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final delay = (index % 6) * 45;
    final duration = AppMotion.durationOf(
      context,
      AppMotion.standard + Duration(milliseconds: delay),
    );
    if (duration == Duration.zero) return child;

    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: AppMotion.entrance,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, value, child) {
        final remaining = 1 - value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: offset * remaining,
            child: Transform.scale(
              scale: 1 - (1 - scale) * remaining,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// 数值变化动画：金额、笔数等数字滚动到新值。
class AnimatedCountText extends StatelessWidget {
  const AnimatedCountText({
    super.key,
    required this.value,
    required this.builder,
    this.duration = AppMotion.data,
    this.curve = AppMotion.entrance,
  });

  final int value;
  final Widget Function(int value) builder;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final effectiveDuration = AppMotion.durationOf(context, duration);
    if (effectiveDuration == Duration.zero) {
      return builder(value);
    }
    return TweenAnimationBuilder<int>(
      duration: effectiveDuration,
      curve: AppMotion.curveOf(context, curve),
      tween: IntTween(begin: 0, end: value),
      builder: (context, current, _) => builder(current),
    );
  }
}

/// 页面切换动画：淡入 + 极轻微上移，避免大幅位移造成视觉噪声。
class AppPageTransition extends PageTransitionsBuilder {
  const AppPageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduceMotionOf(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.entrance,
      reverseCurve: AppMotion.exit,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.016),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
