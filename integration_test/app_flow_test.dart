// On-device / emulator flow test with the REAL Thermion/Filament renderer.
//   flutter test integration_test/app_flow_test.dart -d <device>
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:memoria/app/app.dart';
import 'package:memoria/app/router.dart';
import 'package:memoria/data/demo_data.dart';
import 'package:memoria/data/memory_repository.dart';
import 'package:memoria/scene/scene_controller.dart';
import 'package:memoria/scene/scene_providers.dart';
import 'package:memoria/state/memoria_state.dart';

Future<void> pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

Future<void> pumpUntil(
  WidgetTester t,
  bool Function() cond, {
  Duration timeout = const Duration(seconds: 90),
}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) throw TestFailure('timed out waiting');
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
    'real renderer: explore, focus, rotate, read, evolve, seal, unlock, reveal',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(
            MemoryRepository(InMemoryStore()),
          ),
        ],
      );
      final router = buildRouter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MemoriaApp(router: router),
        ),
      );
      final scene = container.read(sceneControllerProvider);
      final log = <String, Object?>{};

      await pumpUntil(tester, () => scene.ready || scene.initError != null);
      expect(
        scene.initError,
        isNull,
        reason: 'Thermion/Filament must initialise',
      );
      log['renderer'] = 'ready';
      await pumpFor(tester, const Duration(seconds: 2));
      expect(scene.mode, SceneMode.universe);

      // Universe: drag + pinch move the camera within bounds.
      final yaw0 = scene.rig.goalYaw;
      await tester.timedDrag(
        find.byKey(const ValueKey('scene-gesture-layer')).first,
        const Offset(-160, 40),
        const Duration(milliseconds: 500),
      );
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(scene.rig.goalYaw, isNot(yaw0));
      final d0 = scene.rig.goalDistance;
      final center = tester.getCenter(
        find.byKey(const ValueKey('scene-gesture-layer')).first,
      );
      final g1 = await tester.startGesture(
        center - const Offset(40, 0),
        pointer: 7,
      );
      final g2 = await tester.startGesture(
        center + const Offset(40, 0),
        pointer: 8,
      );
      for (var i = 0; i < 10; i++) {
        await g1.moveBy(const Offset(-12, 0));
        await g2.moveBy(const Offset(12, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g1.up();
      await g2.up();
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(
        scene.rig.goalDistance,
        lessThan(d0),
        reason: 'pinch out zooms in',
      );

      // Enter galaxy 2025 (cinematic fly-in).
      await tester.tap(find.text('2025'));
      await pumpUntil(tester, () => scene.mode == SceneMode.galaxy);
      await pumpFor(tester, const Duration(seconds: 2));

      // Select the hero planet via the projected label and enter it.
      final heroLabel = find.byKey(
        const ValueKey('planet-label-${DemoData.heroId}'),
      );
      await pumpUntil(tester, () => heroLabel.evaluate().isNotEmpty);
      container.read(sceneControllerProvider).focusPlanet(DemoData.heroId);
      await pumpFor(tester, const Duration(seconds: 2));
      expect(scene.focusedId, DemoData.heroId);
      router.go('/planet/${DemoData.heroId}');
      await pumpUntil(tester, () => scene.mode == SceneMode.planet);
      await pumpFor(tester, const Duration(seconds: 2));
      await tester.timedDrag(
        find.byKey(const ValueKey('scene-gesture-layer')).first,
        const Offset(180, 0),
        const Duration(milliseconds: 400),
      );
      await pumpFor(tester, const Duration(seconds: 1));

      // Read, switch perspective, return -> evolved planet.
      await tester.tap(find.byKey(const ValueKey('read-memory')));
      await pumpFor(tester, const Duration(seconds: 2));
      await tester.tap(find.byKey(const ValueKey('perspective-1')));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.textContaining('I remember the sound'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('return-to-planet')),
        300,
      );
      await tester.tap(find.byKey(const ValueKey('return-to-planet')));
      await pumpUntil(tester, () => scene.mode == SceneMode.planet);
      await pumpFor(tester, const Duration(seconds: 2));
      expect(
        container.read(memoriaProvider).isEvolved(DemoData.heroId),
        isTrue,
      );

      // Create + seal a capsule, unlock with the prototype clock, full reveal.
      router.go('/create?year=2026');
      await pumpFor(tester, const Duration(seconds: 2));
      await tester.enterText(
        find.byKey(const ValueKey('memory-text')),
        'Emulator capsule',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await pumpFor(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('seal-capsule')));
      await pumpUntil(tester, () => scene.mode == SceneMode.capsule);
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('PROTOTYPE CLOCK'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('prototype-advance-clock')));
      await pumpFor(tester, const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('open-capsule')));
      await pumpUntil(tester, () => scene.mode == SceneMode.reveal);
      final sw = Stopwatch()..start();
      await pumpUntil(
        tester,
        () => scene.mode == SceneMode.planet,
        timeout: const Duration(seconds: 40),
      );
      log['revealSeconds'] = sw.elapsedMilliseconds / 1000;
      await pumpFor(tester, const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('read-revealed')));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('Emulator capsule'), findsOneWidget);
      // ignore: avoid_print
      print('MEMORIA_FLOW ${jsonEncode(log)}');
    },
  );
}
