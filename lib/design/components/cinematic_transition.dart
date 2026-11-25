import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../tokens.dart';

/// Route transition used between spatial levels: the incoming layer fades up
/// from a slight scale with a soft veil of light, so the persistent 3D world
/// behind feels continuous rather than replaced.
CustomTransitionPage<void> cinematicPage({
  required LocalKey key,
  required Widget child,
  bool reducedMotion = false,
}) {
  return CustomTransitionPage<void>(
    key: key,
    opaque: false,
    transitionDuration: reducedMotion
        ? MemoriaDurations.fast
        : MemoriaDurations.slow,
    reverseTransitionDuration: reducedMotion
        ? MemoriaDurations.fast
        : MemoriaDurations.medium,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) =>
        CinematicTransition(
          animation: animation,
          secondary: secondary,
          child: child,
        ),
  );
}

class CinematicTransition extends StatelessWidget {
  const CinematicTransition({
    super.key,
    required this.animation,
    required this.secondary,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inCurve = CurvedAnimation(
      parent: animation,
      curve: MemoriaCurves.gentle,
      reverseCurve: MemoriaCurves.exit,
    );
    final outCurve = CurvedAnimation(
      parent: secondary,
      curve: MemoriaCurves.gentle,
    );
    return AnimatedBuilder(
      animation: Listenable.merge([inCurve, outCurve]),
      builder: (context, _) {
        final t = inCurve.value;
        final o = outCurve.value;
        return Opacity(
          opacity: (t * (1 - o)).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: (1.04 - 0.04 * t) * (1 + 0.03 * o),
            child: child,
          ),
        );
      },
    );
  }
}

/// Full-screen luminous veil used at the climax of camera fly-throughs.
class LightVeil extends StatelessWidget {
  const LightVeil({
    super.key,
    required this.amount,
    this.color = MemoriaColors.memoryGlow,
  });
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (amount <= 0.001) return const SizedBox.shrink();
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 0.9,
            colors: [
              color.withValues(alpha: 0.75 * amount),
              MemoriaColors.midnightTeal.withValues(alpha: 0.6 * amount),
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
