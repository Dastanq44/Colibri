import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Modern minimal loading indicator: a thin sweeping arc with rounded caps
/// (the look current iOS apps use), replacing the dated ticking spinner.
class AppLoader extends StatefulWidget {
  const AppLoader({super.key, this.size = 28, this.strokeWidth = 3, this.color});

  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ??
        Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8);
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: RotationTransition(
          turns: _controller,
          child: CustomPaint(
            painter: _ArcPainter(color: color, strokeWidth: widget.strokeWidth),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: <Color>[color.withValues(alpha: 0), color],
        startAngle: 0,
        endAngle: math.pi * 1.6,
      ).createShader(rect);
    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      0.15,
      math.pi * 1.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
