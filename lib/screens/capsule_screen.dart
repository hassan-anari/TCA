import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/formatting.dart';
import '../data/models.dart';
import '../design/components/celestial_button.dart';
import '../design/components/glass_surface.dart';
import '../design/components/memory_countdown.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../scene/scene_controller.dart';
import '../scene/scene_providers.dart';
import '../scene/scene_viewport.dart';
import '../state/memoria_state.dart';
import 'screen_frame.dart';

/// Screen 05 - Locked Capsule: sealed shell, countdown, no content access.
class CapsuleScreen extends ConsumerStatefulWidget {
  const CapsuleScreen({
    super.key,
    required this.memoryId,
    this.prototypeUnlock = false,
  });
  final String memoryId;

  /// CI/demo hook (`?prototypeClock=unlock`) - same as tapping the clock control.
  final bool prototypeUnlock;

  @override
  ConsumerState<CapsuleScreen> createState() => _CapsuleScreenState();
}

class _CapsuleScreenState extends ConsumerState<CapsuleScreen> {
  Timer? _timer;
  late final SceneController _scene;

  @override
  void initState() {
    super.initState();
    _scene = ref.read(sceneControllerProvider);
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() {}),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _compose());
  }

  Future<void> _compose() async {
    if (!mounted) return;
    _scene.onTap = null;
    await _scene.setActive(true);
    if (!_scene.ready) {
      _scene.addListener(_whenReady);
      return;
    }
    final m = ref.read(memoriaProvider).byId(widget.memoryId);
    if (m == null) return;
    if (widget.prototypeUnlock) {
      await ref.read(memoriaProvider.notifier).advanceClockToUnlock(m);
    }
    await _scene.showCapsule(m);
  }

  void _whenReady() {
    if (_scene.ready) {
      _scene.removeListener(_whenReady);
      _compose();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scene.removeListener(_whenReady);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(memoriaProvider);
    final m = st.byId(widget.memoryId);
    if (m == null) return const SizedBox.shrink();
    final now = st.now();
    final locked = m.isLockedAt(now);
    return ScreenFrame(
      parent: '/galaxy/${m.year}',
      child: Stack(
        children: [
          const Positioned.fill(child: SceneGestureLayer()),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: TitleBar(
              onBack: () => context.go('/galaxy/${m.year}'),
              backLabel: 'Back to ${m.year} galaxy',
              title: m.title,
              eyebrow: locked ? 'A sealed memory capsule' : 'Ready to open',
            ),
          ),
          Positioned(
            left: MemoriaSpacing.screenH,
            right: MemoriaSpacing.screenH,
            bottom: MemoriaSpacing.lg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LockBadge(locked: locked),
                const SizedBox(height: MemoriaSpacing.md),
                if (locked) ...[
                  MemoryCountdown(remaining: m.remainingAt(now)),
                  const SizedBox(height: MemoriaSpacing.sm),
                  Text(
                    'Opens on ${formatDate(m.unlockAt!)}',
                    style: MemoriaType.meta(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Its contents stay sealed until then.',
                    style: MemoriaType.meta(
                      context,
                    ).copyWith(color: MemoriaColors.textTertiary),
                  ),
                  const SizedBox(height: MemoriaSpacing.lg),
                  _PrototypeClock(memory: m),
                ] else ...[
                  Text(
                    'The seal has softened. ${formatDate(m.unlockAt!)} has arrived.',
                    style: MemoriaType.meta(context),
                  ),
                  const SizedBox(height: MemoriaSpacing.lg),
                  CelestialButton(
                    key: const ValueKey('open-capsule'),
                    label: 'Open capsule',
                    icon: LucideIcons.sparkles,
                    onPressed: () => context.go('/reveal/${m.id}'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LockBadge extends StatelessWidget {
  const _LockBadge({required this.locked});
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: locked ? 'Locked' : 'Unlocked',
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: MemoriaColors.memoryGlow.withValues(alpha: 0.6),
            width: 1,
          ),
          gradient: RadialGradient(
            colors: [
              MemoriaColors.memoryGlow.withValues(alpha: 0.28),
              MemoriaColors.memoryGlow.withValues(alpha: 0.02),
            ],
          ),
          boxShadow: MemoriaShadows.glow,
        ),
        child: Icon(
          locked ? LucideIcons.lock : LucideIcons.lockOpen,
          size: 22,
          color: MemoriaColors.memoryGlow,
        ),
      ),
    );
  }
}

/// Clearly labelled prototype-only control that moves the local demo clock.
/// It is NOT a security mechanism: the capsule is plain local data.
class _PrototypeClock extends ConsumerWidget {
  const _PrototypeClock({required this.memory});
  final Memory memory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassSurface(
      radius: MemoriaRadii.md,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          const Icon(
            LucideIcons.clock,
            size: 20,
            color: MemoriaColors.celestialMist,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROTOTYPE CLOCK',
                  style: MemoriaType.eyebrow(
                    context,
                  ).copyWith(letterSpacing: 2.4, fontSize: 10),
                ),
                const SizedBox(height: 2),
                Text(
                  'Demo only · not time-lock security',
                  style: MemoriaType.meta(context).copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          CelestialButton(
            key: const ValueKey('prototype-advance-clock'),
            label: 'Skip to unlock',
            style: CelestialButtonStyle.glass,
            expand: false,
            onPressed: () =>
                ref.read(memoriaProvider.notifier).advanceClockToUnlock(memory),
          ),
        ],
      ),
    );
  }
}
