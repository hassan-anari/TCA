import 'package:flutter/widgets.dart';

import '../tokens.dart';
import 'glass_surface.dart';
import 'pressable.dart';

/// Floating round glass button carrying a single Lucide outline icon.
class CircularIconButton extends StatelessWidget {
  const CircularIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 52,
    this.iconSize = 22,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final s = size < kMinTouchTarget ? kMinTouchTarget : size;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Pressable(
        onPressed: onPressed,
        child: SizedBox.square(
          dimension: s,
          child: GlassSurface(
            radius: s / 2,
            child: Center(
              child: Icon(icon, size: iconSize, color: MemoriaColors.warmIvory),
            ),
          ),
        ),
      ),
    );
  }
}
