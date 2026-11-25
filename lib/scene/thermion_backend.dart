import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide Texture;

import 'scene_backend.dart';

/// Real-time renderer backed by Thermion 0.7.0 (Google Filament v1.77.2).
///
/// One Filament engine + view lives for the whole app session; spatial levels
/// show/hide pooled glTF instances instead of recreating the viewer.
class ThermionSceneBackend implements SceneBackend {
  ThermionViewer? _viewer;
  Camera? _camera;
  ThermionEntity? _keyLight;
  ThermionEntity? _rimLight;
  final Map<String, ThermionAsset> _assets = {};
  final Map<String, Future<ThermionAsset>> _loading = {};
  final Map<String, List<int>> _free = {};
  final Map<int, ThermionAsset> _instances = {};
  final Map<int, String> _keys = {};
  final Map<int, bool> _inScene = {};
  final Map<String, ThermionEntity?> _childCache = {};
  final Map<String, MaterialInstance> _materialCache = {};
  int _next = 1;
  bool _baseInstanceUsed(String key) =>
      _instances.values.contains(_assets[key]);
  bool _rendering = true;
  double _bloom = 0.1;
  QualityTier _tier = QualityTier.high;

  static const double _keyLux = 110000;
  static const double _iblIntensity = 120000;

  @override
  bool get isReady => _viewer != null;

  @override
  Future<void> initialize() async {
    ThermionFlutterPlugin.instance.setOptions(
      const ThermionFlutterOptions(
        nativeOptions: NativeOptions(backend: Backend.OPENGL),
      ),
    );
    final viewer = await ThermionFlutterPlugin.createViewer();
    _viewer = viewer;
    FilamentApp.instance!.setTargetFramerate(60);
    await viewer.setPostProcessing(true);
    // FXAA only: cheap on mobile; MSAA/TAA are left off deliberately.
    await viewer.setAntiAliasing(false, true, false);
    await viewer.setBloom(true, _bloom);
    await viewer.setShadowsEnabled(false);
    try {
      final view = viewer.view;
      final builder = await view.createColorGradingBuilder();
      final mapper = await ToneMapper.agx(
        FilamentApp.instance!,
        look: AgxLook.golden,
      );
      final grading = await builder
          .toneMapper(mapper)
          .saturation(1.04)
          .contrast(1.02)
          .build();
      await view.setColorGrading(grading);
    } catch (e) {
      debugPrint('Memoria: colour grading unavailable ($e)');
    }
    await viewer.loadSkybox('assets/env/nebula_skybox.ktx');
    await viewer.loadIbl('assets/env/nebula_ibl.ktx', intensity: _iblIntensity);
    _keyLight = await viewer.addDirectLight(
      DirectLight(
        type: LightType.DIRECTIONAL,
        color: const LinearColor(1.0, 0.86, 0.72),
        intensity: _keyLux,
        direction: Vector3(-0.55, -0.45, -0.7).normalized(),
        position: Vector3(0, 0, 0),
      ),
    );
    _rimLight = await viewer.addDirectLight(
      DirectLight(
        type: LightType.POINT,
        color: const LinearColor(0.62, 0.82, 0.86),
        intensity: 30000000,
        direction: Vector3(0, 0, -1),
        position: Vector3(6, 3, -6),
        falloffRadius: 40,
      ),
    );
    _camera = await viewer.getActiveCamera();
    // Starfield and veils are always present; preload the heaviest assets.
    await Future.wait([for (final k in SceneAssets.all) _load(k)]);
  }

  Future<ThermionAsset> _load(String key) {
    final existing = _assets[key];
    if (existing != null) return Future.value(existing);
    return _loading.putIfAbsent(key, () async {
      final asset = await _viewer!.loadGltf(
        SceneAssets.path(key),
        addToScene: false,
        releaseSourceData: false,
      );
      _assets[key] = asset;
      return asset;
    });
  }

  @override
  Widget buildView(BuildContext context) {
    final v = _viewer;
    if (v == null) return const SizedBox.expand();
    return ThermionWidget(
      key: const ValueKey('memoria-thermion-view'),
      viewer: v,
    );
  }

  @override
  Future<int> acquire(String assetKey) async {
    final pool = _free[assetKey];
    if (pool != null && pool.isNotEmpty) return pool.removeLast();
    final asset = await _load(assetKey);
    final ThermionAsset instance = _baseInstanceUsed(assetKey)
        ? await asset.createInstance()
        : asset;
    final h = _next++;
    _instances[h] = instance;
    _keys[h] = assetKey;
    _inScene[h] = false;
    return h;
  }

  @override
  Future<void> release(int handle) async {
    await setVisible(handle, false);
    final key = _keys[handle];
    if (key != null) (_free[key] ??= []).add(handle);
  }

  @override
  Future<void> setVisible(int handle, bool visible) async {
    final inst = _instances[handle];
    if (inst == null || _inScene[handle] == visible) return;
    _inScene[handle] = visible;
    if (visible) {
      await _viewer!.addToScene(inst);
    } else {
      await _viewer!.removeFromScene(inst);
    }
  }

  Future<ThermionEntity?> _child(int handle, String name) async {
    final k = '$handle/$name';
    if (_childCache.containsKey(k)) return _childCache[k];
    final e = await _instances[handle]!.getChildEntity(name);
    _childCache[k] = e;
    return e;
  }

  @override
  Future<void> setTransform(
    int handle,
    Matrix4 transform, {
    String? child,
  }) async {
    final inst = _instances[handle];
    if (inst == null) return;
    if (child == null) {
      await inst.setTransform(transform);
    } else {
      final e = await _child(handle, child);
      if (e != null) await inst.setTransform(transform, entity: e);
    }
  }

  @override
  Future<void> setMaterial(
    int handle,
    String child, {
    Vector4? baseColor,
    Vector3? emissive,
  }) async {
    final inst = _instances[handle];
    if (inst == null) return;
    final k = '$handle/$child';
    var mi = _materialCache[k];
    if (mi == null) {
      final e = await _child(handle, child);
      if (e == null) return;
      mi = await inst.getMaterialInstanceAt(entity: e);
      _materialCache[k] = mi;
    }
    if (baseColor != null) {
      await mi.setParameterFloat4(
        'baseColorFactor',
        baseColor.x,
        baseColor.y,
        baseColor.z,
        baseColor.w,
      );
    }
    if (emissive != null) {
      await mi.setParameterFloat3(
        'emissiveFactor',
        emissive.x,
        emissive.y,
        emissive.z,
      );
    }
  }

  @override
  Future<void> setCamera(Vector3 eye, Vector3 target, Vector3 up) async {
    await _camera?.lookAt(eye, focus: target, up: up);
  }

  @override
  Future<void> setProjection(
    double fovYDegrees,
    double aspect,
    double near,
    double far,
  ) async {
    await _camera?.setProjectionFromVerticalFieldOfView(
      fovYDegrees,
      near,
      far,
      aspect,
    );
  }

  @override
  Future<void> setKeyLight({
    required double intensityScale,
    required Vector3 color,
  }) async {
    final l = _keyLight;
    if (l == null) return;
    final lm = FilamentApp.instance!.lightManager;
    lm.setIntensity(l, _keyLux * intensityScale);
    lm.setColor(l, color.x, color.y, color.z);
  }

  @override
  Future<void> setBloom(double strength) async {
    if (_tier == QualityTier.low) strength = 0;
    if ((strength - _bloom).abs() < 0.005) return;
    _bloom = strength;
    await _viewer?.setBloom(strength > 0, strength);
  }

  @override
  Future<void> setRendering(bool enabled) async {
    if (_rendering == enabled) return;
    _rendering = enabled;
    await _viewer?.setRendering(enabled);
  }

  @override
  Future<void> setQuality(QualityTier tier) async {
    if (tier == _tier) return;
    _tier = tier;
    final v = _viewer;
    if (v == null) return;
    await v.view.setRenderQuality(switch (tier) {
      QualityTier.high => QualityLevel.HIGH,
      QualityTier.medium => QualityLevel.MEDIUM,
      QualityTier.low => QualityLevel.LOW,
    });
    await v.setAntiAliasing(false, tier != QualityTier.low, false);
    if (tier == QualityTier.low) await v.setBloom(false, 0);
    if (_rimLight != null && tier == QualityTier.low) {
      FilamentApp.instance!.lightManager.setIntensity(_rimLight!, 0);
    }
  }

  @override
  Future<void> dispose() async {
    final v = _viewer;
    _viewer = null;
    if (v == null) return;
    try {
      await ThermionFlutterPlugin.instance.destroyTextureForView(v.view);
    } catch (_) {}
    await v.dispose();
    await ThermionFlutterPlugin.instance.onViewerDisposed(v.view);
  }
}
