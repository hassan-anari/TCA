import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memoria/data/demo_data.dart';
import 'package:memoria/scene/scene_controller.dart';
import 'package:memoria/scene/scene_providers.dart';
import 'package:memoria/state/memoria_state.dart';

import 'test_app.dart';

void main() {
  testWidgets(
    'universe shows three galaxies with year labels and floating navigation',
    (tester) async {
      final h = await pumpMemoria(tester);
      expect(find.text('My Universe'), findsOneWidget);
      for (final y in ['2024', '2025', '2026']) {
        expect(find.text(y), findsOneWidget);
      }
      expect(
        h.backend.visibleKeys().where((k) => k.startsWith('galaxy_')).length,
        3,
      );
      expect(
        h.container.read(sceneControllerProvider).mode,
        SceneMode.universe,
      );
      expect(find.bySemanticsLabel('New capsule'), findsOneWidget);
    },
  );

  testWidgets(
    'entering a galaxy shows >=5 planets, selection focuses and opens planet',
    (tester) async {
      final h = await pumpMemoria(tester);
      await tester.tap(find.text('2025'));
      await settleFrames(tester, frames: 160);
      final scene = h.container.read(sceneControllerProvider);
      expect(scene.mode, SceneMode.galaxy);
      expect(
        h.backend.visibleKeys().where((k) => k.startsWith('planet_')).length,
        greaterThanOrEqualTo(5),
      );
      expect(find.text('Amber Hearth'.toUpperCase()), findsOneWidget);

      // Tap the projected position of an on-screen, unlocked planet (real hit test).
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      final st = h.container.read(memoriaProvider);
      final target = scene.labels.value.firstWhere((l) {
        final m = st.byId(l.id)!;
        return !m.isLockedAt(st.now()) &&
            l.position.dx > 40 &&
            l.position.dx < size.width - 40 &&
            l.position.dy > 160 &&
            l.position.dy < size.height - 200;
      });
      await tester.tapAt(target.position);
      await settleFrames(tester, frames: 60);
      expect(scene.focusedId, target.id);
      expect(find.text('Enter planet'), findsOneWidget);
      await tester.tap(find.text('Enter planet'));
      await settleFrames(tester, frames: 90);
      expect(scene.mode, SceneMode.planet);
      expect(find.text('Read memory'), findsOneWidget);
    },
  );

  testWidgets(
    'reading switches perspectives and returning evolves the planet',
    (tester) async {
      final h = await pumpMemoria(
        tester,
        location: '/planet/${DemoData.heroId}',
      );
      expect(find.textContaining('new blossoms'), findsNothing);
      await tester.tap(find.text('Read memory'));
      await settleFrames(tester);
      expect(find.text('PERSPECTIVES'), findsOneWidget);
      expect(find.textContaining('waterfall because Maya'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('perspective-1')));
      await settleFrames(tester, frames: 40);
      expect(find.textContaining('I remember the sound'), findsOneWidget);
      expect(
        h.backend.rendering,
        isFalse,
        reason: '3D rendering pauses while reading',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('return-to-planet')),
        300,
      );
      await tester.tap(find.byKey(const ValueKey('return-to-planet')));
      await settleFrames(tester);
      expect(find.textContaining('new blossoms'), findsOneWidget);
      expect(h.backend.visibleKeys(), contains('planet_bloom_evolved'));
      expect(
        h.container.read(memoriaProvider).isEvolved(DemoData.heroId),
        isTrue,
      );
    },
  );

  testWidgets(
    'create -> seal -> locked -> prototype clock -> reveal (skip) -> read',
    (tester) async {
      final h = await pumpMemoria(tester, location: '/create?year=2026');
      expect(find.text('Add a memory'), findsOneWidget);
      expect(
        find.text('Write a few words to seal this capsule.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('memory-title')),
        'Note to self',
      );
      await tester.enterText(
        find.byKey(const ValueKey('memory-text')),
        'Keep the mornings slow.',
      );
      await tester.tap(find.byKey(const ValueKey('kind-shared')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('seal-capsule')));
      await settleFrames(tester);
      final scene = h.container.read(sceneControllerProvider);
      expect(scene.mode, SceneMode.capsule);
      expect(find.text('A SEALED MEMORY CAPSULE'), findsOneWidget);
      expect(find.text('PROTOTYPE CLOCK'), findsOneWidget);
      expect(
        find.text('Read memory'),
        findsNothing,
        reason: 'no access to sealed content',
      );
      expect(h.backend.visibleKeys(), contains('capsule_sealed'));

      await tester.tap(find.byKey(const ValueKey('prototype-advance-clock')));
      await settleFrames(tester, frames: 10);
      await tester.tap(find.byKey(const ValueKey('open-capsule')));
      await settleFrames(tester, frames: 30);
      expect(scene.mode, SceneMode.reveal);
      await tester.tap(find.byKey(const ValueKey('skip-reveal')));
      await settleFrames(tester, frames: 60);
      expect(scene.mode, SceneMode.planet);
      expect(h.backend.visibleKeys(), contains('planet_bloom'));
      await tester.tap(find.byKey(const ValueKey('read-revealed')));
      await settleFrames(tester);
      expect(find.text('Keep the mornings slow.'), findsOneWidget);
    },
  );

  testWidgets('full reveal plays to completion without skipping', (
    tester,
  ) async {
    final h = await pumpMemoria(
      tester,
      location: '/capsule/m-2026-our-capsule?prototypeClock=unlock',
    );
    await tester.tap(find.byKey(const ValueKey('open-capsule')));
    await settleFrames(tester, frames: 30);
    final scene = h.container.read(sceneControllerProvider);
    expect(scene.mode, SceneMode.reveal);
    await settleFrames(tester, frames: 400);
    expect(scene.mode, SceneMode.planet);
    expect(scene.revealProgress.value, 1);
  });

  testWidgets('locked memory cannot be read via a direct route', (
    tester,
  ) async {
    await pumpMemoria(tester, location: '/read/m-2026-letter');
    await settleFrames(tester);
    expect(find.text('A SEALED MEMORY CAPSULE'), findsOneWidget);
    expect(find.textContaining('a whole year has turned'), findsNothing);
  });

  testWidgets('android back from galaxy returns to the universe', (
    tester,
  ) async {
    final h = await pumpMemoria(tester, location: '/galaxy/2024');
    expect(h.container.read(sceneControllerProvider).mode, SceneMode.galaxy);
    final router = GoRouter.of(tester.element(find.text('2024').first));
    await tester.binding.handlePopRoute();
    await settleFrames(tester, frames: 120);
    expect(router.state.uri.path, '/');
    expect(h.container.read(sceneControllerProvider).mode, SceneMode.universe);
  });
}
