import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/formatting.dart';
import '../data/demo_data.dart';
import '../data/models.dart';
import '../design/components/avatar_group.dart';
import '../design/components/celestial_button.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../scene/scene_controller.dart';
import '../scene/scene_providers.dart';
import '../scene/scene_viewport.dart';
import '../state/memoria_state.dart';
import 'screen_frame.dart';

/// Screen 03 - Memory Planet: the miniature world of one unlocked memory.
class PlanetScreen extends ConsumerStatefulWidget {
  const PlanetScreen({
    super.key,
    required this.memoryId,
    this.afterReveal = false,
  });
  final String memoryId;
  final bool afterReveal;

  @override
  ConsumerState<PlanetScreen> createState() => _PlanetScreenState();
}

class _PlanetScreenState extends ConsumerState<PlanetScreen> {
  late final SceneController _scene;

  @override
  void initState() {
    super.initState();
    _scene = ref.read(sceneControllerProvider);
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
    final st = ref.read(memoriaProvider);
    final m = st.byId(widget.memoryId);
    if (m == null) return;
    if (m.isLockedAt(st.now())) {
      if (mounted) context.go('/capsule/${m.id}');
      return;
    }
    await _scene.showPlanet(
      m,
      evolved: m.world == WorldStyle.bloom && st.isEvolved(m.id),
    );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(memoriaProvider);
    final m = st.byId(widget.memoryId);
    if (m == null) return const SizedBox.shrink();
    final people = [for (final id in m.participantIds) DemoData.people[id]!];
    final evolved = m.world == WorldStyle.bloom && st.isEvolved(m.id);
    return ScreenFrame(
      parent: '/galaxy/${m.year}',
      child: Stack(
        children: [
          const Positioned.fill(child: SceneGestureLayer()),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              children: [
                TitleBar(
                  onBack: () => context.go('/galaxy/${m.year}'),
                  backLabel: 'Back to ${m.year} galaxy',
                  title: m.title,
                  eyebrow: m.isShared
                      ? 'A shared memory planet'
                      : 'A personal memory planet',
                ),
                if (m.isShared) ...[
                  const SizedBox(height: MemoriaSpacing.md),
                  AvatarGroup(
                    people: [
                      for (final p in people)
                        AvatarData(
                          name: p.name,
                          colorA: p.colorA,
                          colorB: p.colorB,
                        ),
                    ],
                    size: 46,
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: MemoriaSpacing.screenH,
            right: MemoriaSpacing.screenH,
            bottom: MemoriaSpacing.lg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (evolved)
                  Padding(
                    padding: const EdgeInsets.only(bottom: MemoriaSpacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.sparkles,
                          size: 15,
                          color: MemoriaColors.memoryGlow,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Revisited  ·  new blossoms have grown',
                            style: MemoriaType.meta(
                              context,
                            ).copyWith(color: MemoriaColors.memoryGlow),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(bottom: MemoriaSpacing.md),
                    child: GestureHint(
                      text: 'Drag to turn the world  ·  pinch to zoom',
                    ),
                  ),
                _StatsRow(memory: m, people: people.length),
                const SizedBox(height: MemoriaSpacing.lg),
                CelestialButton(
                  key: const ValueKey('read-memory'),
                  label: 'Read memory',
                  icon: LucideIcons.bookOpen,
                  onPressed: () => context.go('/read/${m.id}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.memory, required this.people});
  final Memory memory;
  final int people;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        memory.isShared ? LucideIcons.users : LucideIcons.user,
        memory.isShared ? '$people Members' : 'Personal',
      ),
      (LucideIcons.feather, 'Created\n${formatShortDate(memory.createdAt)}'),
      (
        LucideIcons.lockOpen,
        memory.unlockAt == null
            ? 'Unlocked\nsince creation'
            : 'Unlocked\n${formatShortDate(memory.unlockAt!)}',
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 44,
              color: MemoriaColors.warmIvory.withValues(alpha: 0.14),
            ),
          Expanded(
            child: Column(
              children: [
                Icon(items[i].$1, size: 21, color: MemoriaColors.softSage),
                const SizedBox(height: 6),
                Text(
                  items[i].$2,
                  textAlign: TextAlign.center,
                  style: MemoriaType.meta(context),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
