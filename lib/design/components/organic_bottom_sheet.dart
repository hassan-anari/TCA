import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// Glass sheet whose top edge is a soft organic wave rather than a straight
/// card edge. Used for planet details and the prototype clock.
class OrganicBottomSheet extends StatelessWidget {
  const OrganicBottomSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 40, 24, 24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const OrganicTopClipper(),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: MemoriaBlur.sheet,
          sigmaY: MemoriaBlur.sheet,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                MemoriaColors.softSage.withValues(alpha: 0.16),
                MemoriaColors.midnightTeal.withValues(alpha: 0.62),
              ],
            ),
          ),
          child: CustomPaint(
            painter: const _OrganicEdgePainter(),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

Path organicTopPath(Size size) {
  const lift = 22.0;
  return Path()
    ..moveTo(0, lift + 8)
    ..cubicTo(
      size.width * 0.22,
      lift - 10,
      size.width * 0.38,
      0,
      size.width * 0.55,
      4,
    )
    ..cubicTo(
      size.width * 0.74,
      9,
      size.width * 0.86,
      lift + 6,
      size.width,
      lift - 2,
    )
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();
}

class OrganicTopClipper extends CustomClipper<Path> {
  const OrganicTopClipper();
  @override
  Path getClip(Size size) => organicTopPath(size);
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _OrganicEdgePainter extends CustomPainter {
  const _OrganicEdgePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = organicTopPath(size);
    final metrics = p.computeMetrics().first;
    final edge = metrics.extractPath(0, metrics.length * 0.33);
    canvas.drawPath(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = const LinearGradient(
          colors: [Color(0x00EEEDE5), Color(0x66EEEDE5), Color(0x00EEEDE5)],
        ).createShader(Offset.zero & Size(size.width, 40)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
