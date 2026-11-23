import 'package:material_ui/material_ui.dart';

import '../core/app_motion.dart';
import '../core/decimal.dart';
import '../core/responsive.dart';
import '../core/theme.dart';

/// 全局背景：浅色渐变 + 两枚柔光色球，给玻璃卡片提供层次。
///
/// 没有模糊滤镜和无限动画，低端机与长时间停留都不会额外耗电。
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppColors.canvasTop,
                  AppColors.canvasBottom,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -150,
          right: -110,
          child: IgnorePointer(
            child: _GlowOrb(
              size: 320,
              color: AppColors.violet.withValues(alpha: 0.14),
            ),
          ),
        ),
        Positioned(
          bottom: -190,
          left: -130,
          child: IgnorePointer(
            child: _GlowOrb(
              size: 360,
              color: AppColors.mint.withValues(alpha: 0.12),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[color, color.withValues(alpha: 0)],
          stops: const <double>[0, 1],
        ),
      ),
    );
  }
}

/// 统一玻璃卡片。
///
/// 用半透明白 + 细边框 + 柔和投影模拟 iOS 27 健身 App 的悬浮卡片质感；
/// 不依赖 BackdropFilter，滚动列表里也能保持稳定帧率。
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.tint,
    this.showSheen = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? tint;
  final bool showSheen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    final effectiveTint = tint ?? AppColors.primary;
    return Container(
      margin: margin ??
          EdgeInsets.symmetric(
            horizontal: Responsive.gutterOf(context),
            vertical: 6,
          ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
        border: Border.all(color: AppColors.outlineSoft),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.055),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: effectiveTint.withValues(alpha: 0.05),
            blurRadius: 36,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: effectiveTint.withValues(alpha: 0.10),
            highlightColor: effectiveTint.withValues(alpha: 0.05),
            child: Stack(
              children: <Widget>[
                if (showSheen)
                  Positioned(
                    top: 0,
                    left: 24,
                    right: 24,
                    height: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.95),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: padding ??
                      EdgeInsets.all(Responsive.cardPaddingOf(context)),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 区块标题：小标题 + 说明 + 可选右侧动作，统一页面节奏。
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.inset = true,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final horizontal = inset ? Responsive.gutterOf(context) : 0.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// 按压反馈：轻微缩放 + 触感，松手立即回弹。
///
/// 只负责视觉反馈，点击行为仍由被子组件（FilledButton 等）处理，
/// 因此不会重复触发业务逻辑。
class PressFeedback extends StatefulWidget {
  const PressFeedback({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = AppMotion.reduceMotionOf(context);
    return AnimatedScale(
      scale: reduce || !_pressed ? 1 : widget.scale,
      duration: AppMotion.feedback,
      curve: AppMotion.entrance,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: reduce ? null : (_) => _setPressed(true),
        onTapUp: reduce ? null : (_) => _setPressed(false),
        onTapCancel: reduce ? null : () => _setPressed(false),
        child: widget.child,
      ),
    );
  }
}

/// 金额文本：数值变化时平滑滚动，最终值与业务数据完全一致。
class AnimatedCurrencyText extends StatelessWidget {
  const AnimatedCurrencyText({
    super.key,
    required this.value,
    this.signed = false,
    this.style,
    this.color,
    this.textAlign = TextAlign.left,
    this.duration = AppMotion.data,
  });

  final Dec value;
  final bool signed;
  final TextStyle? style;
  final Color? color;
  final TextAlign textAlign;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final alignment = switch (textAlign) {
      TextAlign.right => Alignment.centerRight,
      TextAlign.center => Alignment.center,
      _ => Alignment.centerLeft,
    };
    final effectiveStyle = (style ?? Theme.of(context).textTheme.headlineMedium)
        ?.copyWith(color: color);

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: AnimatedCountText(
        value: value.micros,
        duration: duration,
        builder: (micros) {
          final current = Dec.fromMicros(micros);
          return Text(
            signed ? current.signedCurrencyString : current.currencyString,
            maxLines: 1,
            textAlign: textAlign,
            style: effectiveStyle,
          );
        },
      ),
    );
  }
}

/// 指标小块：总览/汇总卡片中统一「标签 + 数字」层级。
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent = AppColors.primary,
    this.align = Alignment.centerLeft,
  });

  final String label;
  final Widget value;
  final IconData? icon;
  final Color accent;
  final Alignment align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 6),
            ],
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 6),
        Align(alignment: align, widthFactor: 1, child: value),
      ],
    );
  }
}
