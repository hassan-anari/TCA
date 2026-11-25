import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';

/// Rendering quality tiers used by the adaptive quality governor.
enum QualityTier { high, medium, low }

/// Runtime GLB assets produced by tools/assets/generate_models.py.
abstract final class SceneAssets {
  static const bloom = 'planet_bloom';
  static const bloomEvolved = 'planet_bloom_evolved';
  static const tide = 'planet_tide';
  static const dune = 'planet_dune';
  static const frost = 'planet_frost';
  static const grove = 'planet_grove';
  static const ember = 'planet_ember';
  static const capsule = 'capsule_sealed';
  static const starfield = 'starfield';
  static const veils = 'nebula_veils';
  static const orbitRing = 'orbit_ring';
  static String galaxy(int year) => 'galaxy_$year';

  static const all = [
    bloom,
    bloomEvolved,
    tide,
    dune,
    frost,
    grove,
    ember,
    capsule,
    starfield,
    veils,
    orbitRing,
    'galaxy_2024',
    'galaxy_2025',
    'galaxy_2026',
  ];

  static String path(String key) => 'assets/models/$key.glb';
}

/// Abstraction over the real-time renderer so scene logic (camera, layout,
/// picking, choreography) is testable without a GPU.
///
/// Handles are opaque integers that refer to one live instance of an asset.
abstract class SceneBackend {
  bool get isReady;

  /// Creates the engine, view, lights and environment.
  Future<void> initialize();

  /// The widget that presents rendered frames (a Flutter Texture on Android).
  Widget buildView(BuildContext context);

  /// Returns a hidden instance of [assetKey] (loading the GLB on first use).
  Future<int> acquire(String assetKey);

  /// Hides an instance and returns it to the pool.
  Future<void> release(int handle);

  Future<void> setVisible(int handle, bool visible);

  /// Sets the root transform, or a named child node's local transform.
  Future<void> setTransform(int handle, Matrix4 transform, {String? child});

  /// Adjusts a named mesh child's material (e.g. dissolving capsule shell).
  Future<void> setMaterial(
    int handle,
    String child, {
    Vector4? baseColor,
    Vector3? emissive,
  });

  Future<void> setCamera(Vector3 eye, Vector3 target, Vector3 up);

  Future<void> setProjection(
    double fovYDegrees,
    double aspect,
    double near,
    double far,
  );

  /// Key light intensity multiplier (1 = default) and colour, for reveal lighting.
  Future<void> setKeyLight({
    required double intensityScale,
    required Vector3 color,
  });

  Future<void> setBloom(double strength);

  /// Pauses/resumes GPU rendering (inactive scenes, background, reading).
  Future<void> setRendering(bool enabled);

  Future<void> setQuality(QualityTier tier);

  Future<void> dispose();
}

/// No-op backend for widget/unit tests and for environments without a GPU.
class NullSceneBackend implements SceneBackend {
  final List<String> log = [];
  final Map<int, String> handles = {};
  final Map<int, bool> visible = {};
  final Map<int, Matrix4> transforms = {};
  int _next = 1;
  bool rendering = true;
  Vector3? lastEye;
  Vector3? lastTarget;

  @override
  bool isReady = false;

  @override
  Future<void> initialize() async {
    isReady = true;
    log.add('init');
  }

  @override
  Widget buildView(BuildContext context) =>
      const ColoredBox(color: Color(0xFF09191D), child: SizedBox.expand());

  @override
  Future<int> acquire(String assetKey) async {
    final h = _next++;
    handles[h] = assetKey;
    visible[h] = false;
    return h;
  }

  @override
  Future<void> release(int handle) async => visible[handle] = false;

  @override
  Future<void> setVisible(int handle, bool v) async => visible[handle] = v;

  @override
  Future<void> setTransform(
    int handle,
    Matrix4 transform, {
    String? child,
  }) async {
    if (child == null) transforms[handle] = transform;
  }

  @override
  Future<void> setMaterial(
    int handle,
    String child, {
    Vector4? baseColor,
    Vector3? emissive,
  }) async {}

  @override
  Future<void> setCamera(Vector3 eye, Vector3 target, Vector3 up) async {
    lastEye = eye;
    lastTarget = target;
  }

  @override
  Future<void> setProjection(
    double fovYDegrees,
    double aspect,
    double near,
    double far,
  ) async {}

  @override
  Future<void> setKeyLight({
    required double intensityScale,
    required Vector3 color,
  }) async {}

  @override
  Future<void> setBloom(double strength) async {}

  @override
  Future<void> setRendering(bool enabled) async => rendering = enabled;

  @override
  Future<void> setQuality(QualityTier tier) async =>
      log.add('quality:${tier.name}');

  @override
  Future<void> dispose() async => log.add('dispose');

  List<String> visibleKeys() => [
    for (final e in visible.entries)
      if (e.value) handles[e.key]!,
  ];
}
