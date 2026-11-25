import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/formatting.dart';
import '../data/demo_data.dart';
import '../data/models.dart';
import '../design/components/atmospheric_background.dart';
import '../design/components/avatar_group.dart';
import '../design/components/celestial_button.dart';
import '../design/components/circular_icon_button.dart';
import '../design/components/pressable.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../scene/scene_providers.dart';
import '../state/memoria_state.dart';
import 'screen_frame.dart';

/// Screen 07 - Memory Reading: editorial reading view with independent
/// perspectives for shared memories. The 3D scene is paused underneath.
class ReadingScreen extends ConsumerStatefulWidget {
  const ReadingScreen({super.key, required this.memoryId});
  final String memoryId;

  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> {
  int _perspective = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final st = ref.read(memoriaProvider);
      final m = st.byId(widget.memoryId);
      if (m != null && m.isLockedAt(st.now())) {
        context.go('/capsule/${m.id}');
        return;
      }
      // Reading is a 2D experience: stop rendering the 3D scene (battery).
      await ref.read(sceneControllerProvider).setActive(false);
    });
  }

  Future<void> _returnToPlanet(Memory m) async {
    await ref.read(memoriaProvider.notifier).recordRevisit(m.id);
    if (mounted) context.go('/planet/${m.id}');
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(memoriaProvider);
    final m = st.byId(widget.memoryId);
    if (m == null || m.isLockedAt(st.now())) return const SizedBox.shrink();
    final reduced = MediaQuery.of(context).disableAnimations;
    final p = m.perspectives[_perspective.clamp(0, m.perspectives.length - 1)];
    final author = DemoData.people[p.authorId]!;
    return ScreenFrame(
      parent: '/planet/${m.id}',
      onBack: () => _returnToPlanet(m),
      child: Stack(
        children: [
          Positioned.fill(
            child: AtmosphericBackground(warmth: 0.75, animate: !reduced),
          ),
          Positioned.fill(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MemoriaSpacing.md,
                      MemoriaSpacing.sm,
                      MemoriaSpacing.md,
                      0,
                    ),
                    child: Row(
                      children: [
                        CircularIconButton(
                          icon: LucideIcons.arrowLeft,
                          semanticLabel: 'Return to planet',
                          onPressed: () => _returnToPlanet(m),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  sliver: SliverList.list(
                    children: [
                      const SizedBox(height: MemoriaSpacing.lg),
                      Text(
                        formatDate(m.memoryDate).toUpperCase(),
                        style: MemoriaType.eyebrow(context),
                      ),
                      const SizedBox(height: MemoriaSpacing.sm),
                      Text(m.title, style: MemoriaType.displayL(context)),
                      const SizedBox(height: MemoriaSpacing.lg),
                      if (m.perspectives.length > 1) ...[
                        Text(
                          'PERSPECTIVES',
                          style: MemoriaType.eyebrow(
                            context,
                          ).copyWith(fontSize: 10),
                        ),
                        const SizedBox(height: MemoriaSpacing.sm),
                        Wrap(
                          spacing: MemoriaSpacing.sm,
                          runSpacing: MemoriaSpacing.sm,
                          children: [
                            for (var i = 0; i < m.perspectives.length; i++)
                              _PerspectiveTab(
                                key: ValueKey('perspective-$i'),
                                person: DemoData
                                    .people[m.perspectives[i].authorId]!,
                                selected: i == _perspective,
                                onTap: () => setState(() => _perspective = i),
                              ),
                          ],
                        ),
                        const SizedBox(height: MemoriaSpacing.lg),
                      ] else ...[
                        Row(
                          children: [
                            AvatarBubble(
                              person: AvatarData(
                                name: author.name,
                                colorA: author.colorA,
                                colorB: author.colorB,
                              ),
                              size: 36,
                            ),
                            const SizedBox(width: MemoriaSpacing.sm),
                            Text(
                              'Written by ${author.name}',
                              style: MemoriaType.label(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: MemoriaSpacing.lg),
                      ],
                      AnimatedSwitcher(
                        duration: reduced
                            ? Duration.zero
                            : MemoriaDurations.medium,
                        child: Text(
                          p.text,
                          key: ValueKey('text-${p.authorId}'),
                          style: MemoriaType.reading(context),
                        ),
                      ),
                      if (m.images.isNotEmpty) ...[
                        const SizedBox(height: MemoriaSpacing.xl),
                        SizedBox(
                          height: 150,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: m.images.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: MemoriaSpacing.sm),
                            itemBuilder: (context, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(
                                MemoriaRadii.md,
                              ),
                              child: AspectRatio(
                                aspectRatio: 0.85,
                                child: _MemoryImage(path: m.images[i]),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: MemoriaSpacing.xl),
                      CelestialButton(
                        key: const ValueKey('return-to-planet'),
                        label: 'Return to Planet',
                        icon: LucideIcons.orbit,
                        onPressed: () => _returnToPlanet(m),
                      ),
                      const SizedBox(height: MemoriaSpacing.xl),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Positioned.fill(child: GrainOverlay(vignette: 0.35)),
        ],
      ),
    );
  }
}

class _PerspectiveTab extends StatelessWidget {
  const _PerspectiveTab({
    super.key,
    required this.person,
    required this.selected,
    required this.onTap,
  });
  final Person person;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: '${person.name} perspective',
      excludeSemantics: true,
      child: Pressable(
        onPressed: onTap,
        child: AnimatedContainer(
          duration: MemoriaDurations.medium,
          padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MemoriaRadii.pill),
            color: MemoriaColors.warmIvory.withValues(
              alpha: selected ? 0.14 : 0.04,
            ),
            border: Border.all(
              color: MemoriaColors.warmIvory.withValues(
                alpha: selected ? 0.3 : 0.1,
              ),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvatarBubble(
                person: AvatarData(
                  name: person.name,
                  colorA: person.colorA,
                  colorB: person.colorB,
                ),
                size: 36,
                highlighted: selected,
              ),
              const SizedBox(width: MemoriaSpacing.xs),
              Text(person.name, style: MemoriaType.label(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoryImage extends StatelessWidget {
  const _MemoryImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover, cacheWidth: 480);
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: 480,
      errorBuilder: (_, _, _) =>
          const ColoredBox(color: MemoriaColors.atmosphere),
    );
  }
}
