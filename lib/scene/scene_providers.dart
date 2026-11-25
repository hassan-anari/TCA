import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'scene_backend.dart';
import 'scene_controller.dart';
import 'thermion_backend.dart';

/// The renderer. Overridden with [NullSceneBackend] in tests.
final sceneBackendProvider = Provider<SceneBackend>(
  (ref) => ThermionSceneBackend(),
);

final sceneControllerProvider = ChangeNotifierProvider<SceneController>((ref) {
  return SceneController(ref.watch(sceneBackendProvider));
});
