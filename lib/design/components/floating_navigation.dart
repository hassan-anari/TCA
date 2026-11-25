import 'package:flutter/widgets.dart';

import '../tokens.dart';
import '../typography.dart';
import 'glass_surface.dart';
import 'pressable.dart';

class FloatingNavItem {
  const FloatingNavItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;
}

/// Minimal floating glass capsule navigation that hovers above the universe.
class FloatingNavigation extends StatelessWidget {
  const FloatingNavigation({super.key, required this.items});

  final List<FloatingNavItem> items;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: MemoriaRadii.pill,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            Semantics(
              button: true,
              selected: item.active,
              label: item.label,
              excludeSemantics: true,
              child: Pressable(
                onPressed: item.onPressed,
                child: AnimatedContainer(
                  duration: MemoriaDurations.medium,
                  curve: MemoriaCurves.standard,
                  constraints: const BoxConstraints(
                    minWidth: 56,
                    minHeight: 52,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(MemoriaRadii.pill),
                    color: item.active
                        ? MemoriaColors.warmIvory.withValues(alpha: 0.14)
                        : const Color(0x00000000),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: 21,
                        color: item.active
                            ? MemoriaColors.memoryGlow
                            : MemoriaColors.softSage,
                      ),
                      if (item.active) ...[
                        const SizedBox(width: 8),
                        Text(item.label, style: MemoriaType.label(context)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
