import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/components/atmospheric_background.dart';
import '../design/components/celestial_button.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../scene/scene_controller.dart';
import '../scene/scene_providers.dart';
import '../state/memoria_state.dart';
import 'screen_frame.dart';

/// Screen 06 - Memory Reveal: the sealed capsule opens into its planet.
/// Skippable; honours the system reduced-motion setting.
class RevealScreen extends ConsumerStatefulWidget {
  const RevealScreen({super.key, required this.memoryId});
  final String memoryId;

  @override
  ConsumerState<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends ConsumerState<RevealScreen> {
  late final SceneController _scene;
  ui.FragmentProgram? _dissolve;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _scene = ref.read(sceneControllerProvider);
    ShaderLibrary.load('shaders/dissolve.frag').then((p) {
      if (mounted) setState(() => _dissolve = p);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (!mounted) return;
    _scene.onTap = null;
    await _scene.setActive(true);
    if (!_scene.ready) {
      _scene.addListener(_whenReady);
      return;
    }
    final st = ref.read(memoriaProvider);
    final m = st.byId(widget.memoryId);
    if (m == null) return;
    if (m.isLockedAt(st.now())) {
      if (!mounted) return;
      // The reveal is only reachable once the (prototype) clock has passed the unlock date.
      context.go('/capsule/${m.id}');
      return;
    }
    await _scene.playReveal(m);
    await ref.read(memoriaProvider.notifier).markRevealed(m.id);
    if (!mounted) return;
    setState(() => _done = true);
  }

  void _whenReady() {
    if (_scene.ready) {
      _scene.removeListener(_whenReady);
      _run();
    }
  }

  @override
  void dispose() {
    _scene.removeListener(_whenReady);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(memoriaProvider).byId(widget.memoryId);
    final scene = ref.watch(sceneControllerProvider);
    return ScreenFrame(
      parent: m == null ? '/' : '/galaxy/${m.year}',
      child: Stack(
        children: [
          if (_dissolve != null)
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<double>(
                  valueListenable: scene.revealProgress,
                  builder: (context, p, _) => CustomPaint(
                    painter: _DissolvePainter(_dissolve!, p, scene.time),
                  ),
                ),
              ),
            ),
          Positioned(
            top: MemoriaSpacing.sm,
            right: MemoriaSpacing.md,
            child: AnimatedOpacity(
              opacity: _done ? 0 : 1,
              duration: MemoriaDurations.medium,
              child: CelestialButton(
                key: const ValueKey('skip-reveal'),
                label: 'Skip',
                icon: LucideIcons.skipForward,
                style: CelestialButtonStyle.glass,
                expand: false,
                onPressed: _done ? null : _scene.skipReveal,
              ),
            ),
          ),
          Positioned(
            left: MemoriaSpacing.screenH,
            right: MemoriaSpacing.screenH,
            bottom: MemoriaSpacing.lg,
            child: ValueListenableBuilder<double>(
              valueListenable: scene.revealProgress,
              builder: (context, p, _) {
                final o = ((p - 0.62) / 0.3).clamp(0.0, 1.0);
                return Opacity(
                  opacity: _done ? 1 : o,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('UNSEALED', style: MemoriaType.eyebrow(context)),
                      const SizedBox(height: MemoriaSpacing.xs),
                      Text(
                        m?.title ?? '',
                        textAlign: TextAlign.center,
                        style: MemoriaType.headingL(context),
                      ),
                      const SizedBox(height: MemoriaSpacing.lg),
                      CelestialButton(
                        key: const ValueKey('read-revealed'),
                        label: 'Read memory',
                        icon: LucideIcons.bookOpen,
                        onPressed: _done && m != null
                            ? () => context.go('/read/${m.id}')
                            : null,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DissolvePainter extends CustomPainter {
  _DissolvePainter(this.program, this.progress, this.time);
  final ui.FragmentProgram program;
  final double progress;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.2 || progress >= 0.98) return;
    final p = ((progress - 0.2) / 0.6).clamp(0.0, 1.0);
    final s = program.fragmentShader()
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, p)
      ..setFloat(4, size.width / 2)
      ..setFloat(5, size.height * 0.46);
    canvas.drawRect(Offset.zero & size, Paint()..shader = s);
  }

  @override
  bool shouldRepaint(covariant _DissolvePainter old) =>
      old.progress != progress;
}
