import 'package:flutter/widgets.dart';

import '../tokens.dart';
import '../typography.dart';
import 'glass_surface.dart';
import 'pressable.dart';

enum CelestialButtonStyle { ivory, glass }

/// Primary pill action. Ivory variant mirrors the concept art's luminous
/// "Save Memory" / "Invite People" buttons; glass variant for secondary use.
class CelestialButton extends StatelessWidget {
  const CelestialButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = CelestialButtonStyle.ivory,
    this.expand = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final CelestialButtonStyle style;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final ivory = style == CelestialButtonStyle.ivory;
    final fg = ivory ? MemoriaColors.inkOnIvory : MemoriaColors.warmIvory;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 21, color: fg),
          const SizedBox(width: MemoriaSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: MemoriaType.button(context).copyWith(color: fg),
          ),
        ),
      ],
    );
    final body = ivory
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MemoriaRadii.pill),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF4F2EA), Color(0xFFE3E0D4)],
              ),
              boxShadow: MemoriaShadows.glow,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              child: content,
            ),
          )
        : GlassSurface(
            radius: MemoriaRadii.pill,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: content,
          );
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onPressed: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTouchTarget),
          child: body,
        ),
      ),
    );
  }
}
