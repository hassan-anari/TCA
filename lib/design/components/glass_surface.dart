import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// Translucent frosted-glass surface: backdrop blur, a soft vertical sheen and
/// a hairline highlight instead of a hard border.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = MemoriaRadii.md,
    this.padding = EdgeInsets.zero,
    this.blur = MemoriaBlur.glass,
    this.strong = false,
    this.tint,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double blur;
  final bool strong;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final base = tint ?? MemoriaColors.softSage;
    final fill = strong
        ? MemoriaOpacity.glassFillStrong
        : MemoriaOpacity.glassFill;
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: shape,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                base.withValues(alpha: fill + 0.06),
                base.withValues(alpha: fill * 0.55),
              ],
            ),
            border: Border.all(
              color: MemoriaColors.warmIvory.withValues(
                alpha: MemoriaOpacity.glassBorder,
              ),
              width: 0.8,
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
