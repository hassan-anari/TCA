import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// 2D elliptical orbital path (interface counterpart of the 3D orbital rings),
/// e.g. around the universe owner's portrait.
class OrbitalHalo extends StatelessWidget {
  const OrbitalHalo({
    super.key,
    required this.child,
    this.tilt = -0.32,
    this.progress = 1,
  });
  final Widget child;
  final double tilt;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _HaloPainter(tilt, progress),
      child: child,
    );
  }
}

class _HaloPainter extends CustomPainter {
  _HaloPainter(this.tilt, this.progress);
  final double tilt;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(tilt);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * 1.7,
      height: size.height * 0.5,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..shader = SweepGradient(
        colors: [
          MemoriaColors.memoryGlow.withValues(alpha: 0.0),
          MemoriaColors.memoryGlow.withValues(alpha: 0.9),
          MemoriaColors.warmIvory.withValues(alpha: 0.4),
          MemoriaColors.memoryGlow.withValues(alpha: 0.0),
        ],
      ).createShader(rect);
    canvas.drawArc(
      rect,
      math.pi * 0.05,
      math.pi * 2 * progress * 0.92,
      false,
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HaloPainter old) =>
      old.progress != progress || old.tilt != tilt;
}
