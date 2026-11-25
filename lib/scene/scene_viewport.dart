import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/components/atmospheric_background.dart';
import '../design/components/cinematic_transition.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'quality_governor.dart';
import 'scene_controller.dart';
import 'scene_providers.dart';

/// Persistent full-screen 3D layer shared by every spatial screen. Owns the
/// frame ticker, gesture capture, grain/vignette and the light veil.
class SceneViewport extends ConsumerStatefulWidget {
  const SceneViewport({super.key});

  @override
  ConsumerState<SceneViewport> createState() => _SceneViewportState();
}

class _SceneViewportState extends ConsumerState<SceneViewport>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  QualityGovernor? _governor;
  late final SceneController _c;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick)..start();
    _c = ref.read(sceneControllerProvider);
    if (_c.mode == SceneMode.loading && _c.initError == null) _c.start();
    _governor = QualityGovernor(_c.backend)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _c.tick(dt);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    // Stop GPU work and the frame ticker while backgrounded (battery).
    _c.setActive(active);
    if (active && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!active && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _governor?.stop();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sceneControllerProvider);
    final reduced = MediaQuery.of(context).disableAnimations;
    c.reducedMotion = reduced;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, box) {
            c.setViewport(box.biggest);
            return Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: MemoriaColors.deepSpace),
                if (c.ready)
                  RepaintBoundary(child: c.backend.buildView(context)),
                if (!c.ready) _LoadingOrError(error: c.initError),
                GrainOverlay(animate: !reduced),
                ValueListenableBuilder<double>(
                  valueListenable: c.veil,
                  builder: (context, v, _) => LightVeil(amount: v),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _LoadingOrError extends StatelessWidget {
  const _LoadingOrError({this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const AtmosphericBackground(warmth: 0.5),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              error == null
                  ? 'Gathering your universe'
                  : 'The 3D renderer could not start on this device.\n$error',
              textAlign: TextAlign.center,
              style: error == null
                  ? MemoriaType.headingM(context)
                  : MemoriaType.meta(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// Captures camera gestures for the 3D scene. Each spatial screen places it at
/// the bottom of its own overlay stack (inside the route, so the navigator's
/// modal barrier never swallows touches and overlay controls always win).
class SceneGestureLayer extends ConsumerWidget {
  const SceneGestureLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sceneControllerProvider);
    return GestureDetector(
      key: const ValueKey('scene-gesture-layer'),
      behavior: HitTestBehavior.opaque,
      onScaleStart: (d) => c.onScaleStart(d.pointerCount),
      onScaleUpdate: (d) => c.onScaleUpdate(
        focalDelta: d.focalPointDelta,
        scale: d.scale,
        pointerCount: d.pointerCount,
      ),
      onScaleEnd: (d) => c.onScaleEnd(d.velocity, d.pointerCount),
      onTapUp: (d) => c.onTap?.call(c.hitTest(d.globalPosition)),
    );
  }
}
