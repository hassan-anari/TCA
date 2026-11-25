import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoria/app/app.dart';
import 'package:memoria/app/router.dart';
import 'package:memoria/data/memory_repository.dart';
import 'package:memoria/scene/scene_backend.dart';
import 'package:memoria/scene/scene_providers.dart';
import 'package:memoria/state/memoria_state.dart';

class TestHarness {
  TestHarness(this.backend, this.store, this.container);
  final NullSceneBackend backend;
  final InMemoryStore store;
  final ProviderContainer container;
}

/// Pumps the real app with a no-op renderer and in-memory persistence.
Future<TestHarness> pumpMemoria(
  WidgetTester tester, {
  String location = '/',
  InMemoryStore? store,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final backend = NullSceneBackend();
  final s = store ?? InMemoryStore();
  final container = ProviderContainer(
    overrides: [
      sceneBackendProvider.overrideWithValue(backend),
      repositoryProvider.overrideWithValue(MemoryRepository(s)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MemoriaApp(router: buildRouter(initialLocation: location)),
    ),
  );
  await settleFrames(tester);
  return TestHarness(backend, s, container);
}

/// Advances time frame-by-frame (the scene ticker never "settles").
Future<void> settleFrames(WidgetTester tester, {int frames = 90}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
