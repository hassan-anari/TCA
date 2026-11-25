// Frame-timing capture over a scripted exploration (run in --profile):
//   flutter drive --profile --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart
// NOTE: on CI this runs on an x86_64 emulator with SwiftShader (software GPU).
// Those numbers are NOT representative of a physical device.
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

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('frame timings: universe, galaxy, planet, reveal', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(MemoryRepository(InMemoryStore())),
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
    final end = DateTime.now().add(const Duration(seconds: 90));
    while (!scene.ready &&
        scene.initError == null &&
        DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(scene.initError, isNull);

    Future<void> live(Duration d) async {
      final e = DateTime.now().add(d);
      while (DateTime.now().isBefore(e)) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    final layer = find.byKey(const ValueKey('scene-gesture-layer')).first;
    await binding.watchPerformance(() async {
      await live(const Duration(seconds: 3));
      await tester.timedDrag(
        layer,
        const Offset(-200, 60),
        const Duration(seconds: 1),
      );
      await live(const Duration(seconds: 2));
    }, reportKey: 'universe');

    router.go('/galaxy/2025');
    await live(const Duration(seconds: 3));
    await binding.watchPerformance(() async {
      await tester.timedDrag(
        find.byKey(const ValueKey('scene-gesture-layer')).first,
        const Offset(220, -40),
        const Duration(seconds: 1),
      );
      await live(const Duration(seconds: 2));
      scene.focusPlanet(DemoData.heroId);
      await live(const Duration(seconds: 3));
    }, reportKey: 'galaxy');

    router.go('/planet/${DemoData.heroId}');
    await live(const Duration(seconds: 3));
    await binding.watchPerformance(() async {
      await tester.timedDrag(
        find.byKey(const ValueKey('scene-gesture-layer')).first,
        const Offset(240, 0),
        const Duration(seconds: 1),
      );
      await live(const Duration(seconds: 3));
    }, reportKey: 'planet');

    router.go('/capsule/m-2026-our-capsule?prototypeClock=unlock');
    await live(const Duration(seconds: 3));
    router.go('/reveal/m-2026-our-capsule');
    await binding.watchPerformance(() async {
      final e = DateTime.now().add(const Duration(seconds: 30));
      while (scene.mode != SceneMode.planet && DateTime.now().isBefore(e)) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await live(const Duration(seconds: 1));
    }, reportKey: 'reveal');
  });
}
