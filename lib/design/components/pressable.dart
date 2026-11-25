import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// Shared press feedback: a soft scale + fade, no ripples.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onPressed});

  final Widget child;
  final VoidCallback? onPressed;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: MemoriaDurations.fast,
        curve: MemoriaCurves.standard,
        child: AnimatedOpacity(
          opacity: enabled ? (_down ? 0.82 : 1) : MemoriaOpacity.disabled,
          duration: MemoriaDurations.fast,
          child: widget.child,
        ),
      ),
    );
  }
}
