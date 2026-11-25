import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/formatting.dart';
import '../data/demo_data.dart';
import '../data/models.dart';
import '../design/components/celestial_button.dart';
import '../design/components/circular_icon_button.dart';
import '../design/components/organic_bottom_sheet.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../scene/scene_controller.dart';
import '../scene/scene_providers.dart';
import '../scene/scene_viewport.dart';
import '../state/memoria_state.dart';
import 'screen_frame.dart';

/// Screen 02 - Galaxy Exploration: memory planets orbiting in a real 3D year.
class GalaxyScreen extends ConsumerStatefulWidget {
  const GalaxyScreen({super.key, required this.year, this.initialFocus});
  final int year;

  /// Optional deep-link focus (`?focus=<memoryId>`), used by the CI screenshot run.
  final String? initialFocus;

  @override
  ConsumerState<GalaxyScreen> createState() => _GalaxyScreenState();
}

class _GalaxyScreenState extends ConsumerState<GalaxyScreen> {
  String? _selected;

  late final SceneController _scene;

  @override
  void initState() {
    super.initState();
    _scene = ref.read(sceneControllerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _compose());
  }

  Future<void> _compose() async {
    if (!mounted) return;
    _scene.onTap = _onSceneTap;
    await _scene.setActive(true);
    if (!_scene.ready) {
      _scene.addListener(_whenReady);
      return;
    }
    final st = ref.read(memoriaProvider);
    await _scene.showGalaxy(
      widget.year,
      st.forYear(widget.year),
      now: st.now(),
      evolved: (m) => m.world == WorldStyle.bloom && st.isEvolved(m.id),
    );
    if (mounted && widget.initialFocus != null) select(widget.initialFocus);
  }

  void _whenReady() {
    if (_scene.ready) {
      _scene.removeListener(_whenReady);
      _compose();
    }
  }

  @override
  void dispose() {
    _scene.removeListener(_whenReady);
    if (_scene.onTap == _onSceneTap) _scene.onTap = null;
    super.dispose();
  }

  void _onSceneTap(SceneHit? hit) => select(hit?.memoryId);

  void select(String? id) {
    setState(() => _selected = id);
    if (id == null) {
      _scene.clearFocus();
    } else {
      _scene.focusPlanet(id);
    }
  }

  void _open(Memory m) {
    final st = ref.read(memoriaProvider);
    if (m.isLockedAt(st.now())) {
      context.go('/capsule/${m.id}');
    } else {
      context.go('/planet/${m.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scene = ref.watch(sceneControllerProvider);
    final st = ref.watch(memoriaProvider);
    final info = DemoData.galaxies.firstWhere(
      (g) => g.year == widget.year,
      orElse: () => DemoData.galaxies[1],
    );
    final selected = _selected == null ? null : st.byId(_selected!);
    final now = st.now();
    return ScreenFrame(
      parent: '/?from=${widget.year}',
      child: Stack(
        children: [
          const Positioned.fill(child: SceneGestureLayer()),
          Positioned.fill(
            child: ValueListenableBuilder<List<SceneLabel>>(
              valueListenable: scene.labels,
              builder: (context, labels, _) => Stack(
                children: [
                  if (scene.mode == SceneMode.galaxy)
                    for (final l in labels)
                      if (st.byId(l.id) case final m?)
                        _PlanetLabel(
                          key: ValueKey('planet-label-${l.id}'),
                          label: l,
                          memory: m,
                          locked: m.isLockedAt(now),
                          selected: l.id == _selected,
                          onTap: () => select(l.id),
                        ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: TitleBar(
              onBack: () => context.go('/?from=${widget.year}'),
              backLabel: 'Back to universe',
              title: '${widget.year}',
              eyebrow: info.name,
              trailing: CircularIconButton(
                icon: LucideIcons.plus,
                semanticLabel: 'New memory capsule',
                onPressed: () => context.go('/create?year=${widget.year}'),
              ),
            ),
          ),
          if (selected == null)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: GestureHint(
                text: 'Drag to orbit  ·  pinch to zoom  ·  tap a planet',
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSwitcher(
              duration: MemoriaDurations.medium,
              switchInCurve: MemoriaCurves.gentle,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.25),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
              ),
              child: selected == null
                  ? const SizedBox.shrink()
                  : _PlanetSheet(
                      key: ValueKey(selected.id),
                      memory: selected,
                      locked: selected.isLockedAt(now),
                      now: now,
                      onOpen: () => _open(selected),
                      onClose: () => select(null),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanetLabel extends StatelessWidget {
  const _PlanetLabel({
    super.key,
    required this.label,
    required this.memory,
    required this.locked,
    required this.selected,
    required this.onTap,
  });

  final SceneLabel label;
  final Memory memory;
  final bool locked;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final opacity = (1.25 - label.depth / 30).clamp(0.25, 1.0);
    final icon = locked
        ? LucideIcons.lock
        : (memory.isShared ? LucideIcons.users : LucideIcons.user);
    return Positioned(
      left: label.position.dx - 90,
      top: label.position.dy + label.radius + 4,
      width: 180,
      child: Opacity(
        opacity: selected ? 1 : opacity,
        child: Semantics(
          button: true,
          label:
              '${memory.title}, ${locked ? 'locked capsule' : (memory.isShared ? 'shared memory' : 'personal memory')}',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 13,
                    color: locked
                        ? MemoriaColors.memoryGlow
                        : MemoriaColors.softSage,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      memory.title,
                      overflow: TextOverflow.ellipsis,
                      style: MemoriaType.meta(context).copyWith(
                        fontSize: 12,
                        color: selected
                            ? MemoriaColors.warmIvory
                            : MemoriaColors.textSecondary,
                      ),
                    ),
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

class _PlanetSheet extends StatelessWidget {
  const _PlanetSheet({
    super.key,
    required this.memory,
    required this.locked,
    required this.now,
    required this.onOpen,
    required this.onClose,
  });

  final Memory memory;
  final bool locked;
  final DateTime now;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return OrganicBottomSheet(
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    memory.title,
                    style: MemoriaType.headingM(context),
                  ),
                ),
                CircularIconButton(
                  icon: LucideIcons.x,
                  onPressed: onClose,
                  semanticLabel: 'Close',
                  size: 48,
                  iconSize: 18,
                ),
              ],
            ),
            const SizedBox(height: MemoriaSpacing.xs),
            Wrap(
              spacing: MemoriaSpacing.md,
              runSpacing: MemoriaSpacing.xs,
              children: [
                _Chip(
                  icon: LucideIcons.calendar,
                  text: formatShortDate(memory.memoryDate),
                ),
                _Chip(
                  icon: memory.isShared ? LucideIcons.users : LucideIcons.user,
                  text: memory.isShared ? 'Shared' : 'Personal',
                ),
                _Chip(
                  icon: locked ? LucideIcons.lock : LucideIcons.lockOpen,
                  text: locked
                      ? formatRemaining(memory.remainingAt(now))
                      : 'Unlocked',
                  warm: locked,
                ),
              ],
            ),
            const SizedBox(height: MemoriaSpacing.lg),
            CelestialButton(
              label: locked ? 'View sealed capsule' : 'Enter planet',
              icon: locked ? LucideIcons.lock : LucideIcons.orbit,
              onPressed: onOpen,
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, this.warm = false});
  final IconData icon;
  final String text;
  final bool warm;

  @override
  Widget build(BuildContext context) {
    final c = warm ? MemoriaColors.memoryGlow : MemoriaColors.softSage;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 6),
        Text(text, style: MemoriaType.meta(context).copyWith(color: c)),
      ],
    );
  }
}
