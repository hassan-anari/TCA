import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/demo_data.dart';
import '../design/components/floating_navigation.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../scene/scene_controller.dart';
import '../scene/scene_providers.dart';
import '../scene/scene_viewport.dart';
import '../state/memoria_state.dart';
import 'screen_frame.dart';

/// Screen 01 - Personal Universe: three galaxies (2024-2026) in real 3D.
class UniverseScreen extends ConsumerStatefulWidget {
  const UniverseScreen({super.key, this.fromYear});
  final int? fromYear;

  @override
  ConsumerState<UniverseScreen> createState() => _UniverseScreenState();
}

class _UniverseScreenState extends ConsumerState<UniverseScreen> {
  bool _entering = false;

  @override
  void initState() {
    super.initState();
    _scene = ref.read(sceneControllerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _compose());
  }

  late final SceneController _scene;

  Future<void> _compose() async {
    if (!mounted) return;
    _scene.onTap = _onSceneTap;
    await _scene.setActive(true);
    if (_scene.mode == SceneMode.loading) {
      _scene.addListener(_onSceneReady);
    } else if (_scene.mode != SceneMode.universe) {
      await _scene.showUniverse(fromYear: widget.fromYear);
    }
  }

  void _onSceneReady() {
    if (_scene.ready) {
      _scene.removeListener(_onSceneReady);
      _scene.showUniverse();
    }
  }

  @override
  void dispose() {
    _scene.removeListener(_onSceneReady);
    if (_scene.onTap == _onSceneTap) _scene.onTap = null;
    super.dispose();
  }

  void _onSceneTap(SceneHit? hit) {
    if (hit?.year != null) enterGalaxy(hit!.year!);
  }

  Future<void> enterGalaxy(int year) async {
    if (_entering) return;
    setState(() => _entering = true);
    await _scene.flyIntoGalaxy(year);
    if (mounted) context.go('/galaxy/$year');
  }

  @override
  Widget build(BuildContext context) {
    final scene = ref.watch(sceneControllerProvider);
    final memories = ref.watch(memoriaProvider);
    return ScreenFrame(
      child: Stack(
        children: [
          const Positioned.fill(child: SceneGestureLayer()),
          // Year labels that follow the real 3D galaxies.
          Positioned.fill(
            child: ValueListenableBuilder<List<SceneLabel>>(
              valueListenable: scene.labels,
              builder: (context, labels, _) => Stack(
                children: [
                  for (final l in labels)
                    if (scene.mode == SceneMode.universe)
                      _GalaxyLabel(
                        key: ValueKey('galaxy-label-${l.id}'),
                        label: l,
                        count: memories.forYear(int.parse(l.id)).length,
                        onTap: () => enterGalaxy(int.parse(l.id)),
                      ),
                ],
              ),
            ),
          ),
          Positioned(
            top: MemoriaSpacing.md,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Column(
                children: [
                  Text('My Universe', style: MemoriaType.displayL(context)),
                  const SizedBox(height: MemoriaSpacing.xs),
                  Text(
                    'YOUR PERSONAL MEMORY SPACE',
                    style: MemoriaType.eyebrow(context),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 112,
            child: GestureHint(
              text: 'Drag to drift  ·  pinch to zoom  ·  tap a galaxy to enter',
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MemoriaSpacing.lg,
            child: Center(
              child: FloatingNavigation(
                items: [
                  FloatingNavItem(
                    icon: LucideIcons.orbit,
                    label: 'Universe',
                    active: true,
                    onPressed: () {},
                  ),
                  FloatingNavItem(
                    icon: LucideIcons.feather,
                    label: 'New capsule',
                    onPressed: () => context.go('/create'),
                  ),
                  FloatingNavItem(
                    icon: LucideIcons.hourglass,
                    label: 'Capsules',
                    onPressed: () => enterGalaxy(DemoData.galaxies.last.year),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalaxyLabel extends StatelessWidget {
  const _GalaxyLabel({
    super.key,
    required this.label,
    required this.count,
    required this.onTap,
  });
  final SceneLabel label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final info = DemoData.galaxies.firstWhere((g) => '${g.year}' == label.id);
    final size = MediaQuery.sizeOf(context);
    // Keep labels on screen and fade them with depth.
    final x = label.position.dx.clamp(70.0, size.width - 70.0);
    final y = (label.position.dy + label.radius * 0.55).clamp(
      80.0,
      size.height - 160.0,
    );
    final opacity = (1.4 - label.depth / 40).clamp(0.35, 1.0);
    return Positioned(
      left: x - 80,
      top: y,
      width: 160,
      child: Opacity(
        opacity: opacity,
        child: Semantics(
          button: true,
          label: 'Enter ${info.year} galaxy, ${info.name}, $count memories',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: kMinTouchTarget),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${info.year}', style: MemoriaType.year(context)),
                  Text(
                    info.name.toUpperCase(),
                    style: MemoriaType.eyebrow(
                      context,
                    ).copyWith(fontSize: 10, letterSpacing: 3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
