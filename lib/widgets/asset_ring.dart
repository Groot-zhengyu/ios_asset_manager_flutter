import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/app_motion.dart';
import '../core/theme.dart';

/// 环形图的一段数据。
class AssetRingSegment {
  const AssetRingSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

/// iOS 健身风格的分段进度环：细轨道、圆头弧线、柔光晕、顺时针生长。
///
/// 数据变化时重新播放一次有限生长动画；系统开启「减少动态效果」时直接显示终态。
class AssetRing extends StatefulWidget {
  const AssetRing({
    super.key,
    required this.segments,
    required this.size,
    required this.strokeWidth,
    this.center,
  });

  final List<AssetRingSegment> segments;
  final double size;
  final double strokeWidth;
  final Widget? center;

  @override
  State<AssetRing> createState() => _AssetRingState();
}

class _AssetRingState extends State<AssetRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late String _signature;

  @override
  void initState() {
    super.initState();
    _signature = _signatureOf(widget.segments);
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.data,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.entrance,
    );
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceMotionOf(context)) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(AssetRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _signatureOf(widget.segments);
    if (next == _signature) return;
    _signature = next;
    if (AppMotion.reduceMotionOf(context)) {
      _controller.value = 1;
    } else {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _signatureOf(List<AssetRingSegment> segments) => segments
      .map(
        (segment) =>
            '${segment.label}:${segment.value.toStringAsFixed(2)}:${segment.color.toARGB32()}',
      )
      .join('|');

  @override
  Widget build(BuildContext context) {
    final description = widget.segments
        .map((segment) => '${segment.label} ${segment.value.toStringAsFixed(0)}')
        .join('，');

    return Semantics(
      container: true,
      label: '资产分布环形图：$description',
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) => SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            key: const ValueKey('asset-donut'),
            painter: _AssetRingPainter(
              segments: widget.segments,
              progress: _animation.value,
              strokeWidth: widget.strokeWidth,
            ),
            child: Center(child: widget.center),
          ),
        ),
      ),
    );
  }
}

class _AssetRingPainter extends CustomPainter {
  const _AssetRingPainter({
    required this.segments,
    required this.progress,
    required this.strokeWidth,
  });

  final List<AssetRingSegment> segments;
  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final trackPaint = Paint()
      ..color = AppColors.track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    if (progress <= 0) return;
    final total = segments.fold<double>(
      0,
      (sum, segment) => sum + (segment.value > 0 ? segment.value : 0),
    );
    if (total <= 0) return;

    const gap = 0.075; // 段间留白，圆头不互相覆盖。
    var startAngle = -math.pi / 2;
    for (final segment in segments) {
      if (segment.value <= 0) continue;
      final fullSweep = segment.value / total * math.pi * 2;
      final drawnSweep = fullSweep * progress;
      final visibleSweep = (drawnSweep - gap).clamp(0.0, math.pi * 2).toDouble();
      if (visibleSweep > 0) {
        final arcStart = startAngle + gap / 2;

        // 柔光：比主体略宽的半透明描边，营造健身环形图的发光质感。
        canvas.drawArc(
          rect,
          arcStart,
          visibleSweep,
          false,
          Paint()
            ..color = segment.color.withValues(alpha: 0.16)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth + 7
            ..strokeCap = StrokeCap.round,
        );

        canvas.drawArc(
          rect,
          arcStart,
          visibleSweep,
          false,
          Paint()
            ..color = segment.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round,
        );
      }
      startAngle += fullSweep * progress;
    }
  }

  @override
  bool shouldRepaint(covariant _AssetRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.segments != segments;
}
