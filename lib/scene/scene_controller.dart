import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show Velocity;
import 'package:vector_math/vector_math_64.dart';

import '../data/models.dart';
import 'camera_rig.dart';
import 'scene_backend.dart';
import 'scene_layout.dart';

enum SceneMode { loading, universe, galaxy, planet, capsule, reveal }

/// What a tap in the 3D view landed on.
class SceneHit {
  const SceneHit({this.year, this.memoryId});
  final int? year;
  final String? memoryId;
}

/// A screen-space anchor for a Flutter label that tracks a 3D entity.
class SceneLabel {
  const SceneLabel({
    required this.id,
    required this.position,
    required this.radius,
    required this.depth,
  });
  final String id;
  final Offset position;
  final double radius;
  final double depth;
}

/// One pooled instance placed in the scene.
class _Placed {
  _Placed(this.handle, this.key);
  final int handle;
  final String key;
  String? memoryId;
  int? year;
  Orbit? orbit;
  double scale = 1;
  bool locked = false;
  double spin = 0;
  Vector3 position = Vector3.zero();
}

/// Owns scene composition, camera choreography, ambient animation, picking and
/// the reveal sequence. Renderer-agnostic: talks to a [SceneBackend].
class SceneController extends ChangeNotifier {
  SceneController(this.backend);

  final SceneBackend backend;
  final CameraRig rig = CameraRig(fovY: 42);

  SceneMode _mode = SceneMode.loading;
  SceneMode get mode => _mode;

  Object? initError;
  bool get ready => _mode != SceneMode.loading && initError == null;

  Size _viewport = const Size(400, 800);
  Size get viewport => _viewport;

  double _t = 0;
  double get time => _t;
  bool reducedMotion = false;

  /// 0..1 light veil drawn by the UI during fly-through transitions.
  final ValueNotifier<double> veil = ValueNotifier(0);

  /// Projected anchors (galaxy year labels / planet labels).
  final ValueNotifier<List<SceneLabel>> labels = ValueNotifier(const []);

  /// Reveal progress 0..1 (drives the Flutter dissolve overlay).
  final ValueNotifier<double> revealProgress = ValueNotifier(0);

  int? _starfield;
  int? _veils;
  final Map<int, _Placed> _galaxies = {};
  final List<_Placed> _planets = [];
  final List<_Placed> _rings = [];
  _Placed? _hero; // planet / capsule shown on its own
  _Placed? _revealPlanet;
  int? _activeYear;
  String? _focusedId;
  String? get focusedId => _focusedId;

  // planet-object rotation (planet & capsule modes)
  double _objYaw = 0.5,
      _objPitch = 0.05,
      _goalObjYaw = 0.5,
      _goalObjPitch = 0.05;
  double _objYawVel = 0;
  double _lastInteraction = -10;

  bool _pushing = false;

  /// Set by the active screen to receive taps on 3D entities.
  void Function(SceneHit? hit)? onTap;
  double _lastAspect = 0;

  // ------------------------------------------------------------ lifecycle
  Future<void> start() async {
    try {
      await backend.initialize();
      _starfield = await backend.acquire(SceneAssets.starfield);
      _veils = await backend.acquire(SceneAssets.veils);
      await backend.setVisible(_starfield!, true);
      await backend.setVisible(_veils!, true);
      for (final y in const [2024, 2025, 2026]) {
        final p = _Placed(
          await backend.acquire(SceneAssets.galaxy(y)),
          SceneAssets.galaxy(y),
        )..year = y;
        _galaxies[y] = p;
      }
      _mode = SceneMode.universe;
      await _composeUniverse();
    } catch (e, st) {
      initError = e;
      debugPrint('Memoria scene init failed: $e\n$st');
    }
    notifyListeners();
  }

  void setViewport(Size size) {
    if (size.isEmpty) return;
    _viewport = size;
  }

  // -------------------------------------------------------------- frame tick
  /// Called every vsync by the viewport's ticker.
  void tick(double dt) {
    if (_disposed || _mode == SceneMode.loading) return;
    _t += dt;
    rig.update(dt);
    final a = 1 - math.exp(-7 * dt);
    if (_mode == SceneMode.planet || _mode == SceneMode.capsule) {
      if (!reducedMotion && _t - _lastInteraction > 3.5) {
        _goalObjYaw += dt * 0.06;
      }
      if (_objYawVel.abs() > 1e-4) {
        _goalObjYaw += _objYawVel * dt;
        _objYawVel *= math.exp(-3.0 * dt);
      }
      _objYaw += (_goalObjYaw - _objYaw) * a;
      _objPitch += (_goalObjPitch - _objPitch) * a;
    }
    if (_focusedId != null && _mode == SceneMode.galaxy) {
      final f = _planets.where((p) => p.memoryId == _focusedId).firstOrNull;
      if (f != null) rig.setGoal(target: f.position);
    }
    _updateLabels();
    _push();
  }

  /// Sends one frame of transforms + camera to the renderer. Skips a frame if
  /// the previous batch has not been consumed yet (prevents queue build-up).
  void _push() {
    if (_pushing || !backend.isReady) return;
    _pushing = true;
    final futures = <Future<void>>[];
    final aspect = _viewport.width / math.max(1, _viewport.height);
    if ((aspect - _lastAspect).abs() > 1e-3) {
      _lastAspect = aspect;
      futures.add(backend.setProjection(rig.fovY, aspect, 0.05, 400));
    }
    futures.add(backend.setCamera(rig.eye, rig.target, rig.up));
    final amb = reducedMotion ? 0.0 : _t;
    switch (_mode) {
      case SceneMode.universe:
        for (final g in _galaxies.values) {
          futures.add(
            backend.setTransform(
              g.handle,
              SceneLayout.universeGalaxyTransform(g.year!, amb),
            ),
          );
        }
      case SceneMode.galaxy:
        final g = _galaxies[_activeYear];
        if (g != null) {
          futures.add(
            backend.setTransform(
              g.handle,
              SceneLayout.galaxyBackdropTransform(g.year!, amb),
            ),
          );
        }
        for (final p in _planets) {
          p.position = p.orbit!.positionAt(amb);
          futures.add(
            backend.setTransform(
              p.handle,
              _planetMatrix(p.position, p.scale, amb * 0.15 + p.spin),
            ),
          );
          if (p.memoryId == _focusedId || _planets.length < 7) {
            futures.addAll(_ambientChildren(p, amb));
          }
        }
      case SceneMode.planet:
      case SceneMode.capsule:
      case SceneMode.reveal:
        final h = _hero;
        if (h != null) {
          futures.add(backend.setTransform(h.handle, _heroMatrix(h.scale)));
          // During the reveal the choreography owns the capsule's children.
          if (_mode != SceneMode.reveal) {
            futures.addAll(_ambientChildren(h, amb));
          }
        }
        final rp = _revealPlanet;
        if (rp != null) {
          futures.add(backend.setTransform(rp.handle, _heroMatrix(rp.scale)));
          futures.addAll(_ambientChildren(rp, amb));
        }
      case SceneMode.loading:
        break;
    }
    Future.wait(futures).whenComplete(() => _pushing = false);
  }

  Matrix4 _planetMatrix(Vector3 pos, double scale, double spin) =>
      Matrix4.identity()
        ..translateByVector3(pos)
        ..rotateY(spin)
        ..scaleByDouble(scale, scale, scale, 1);

  Matrix4 _heroMatrix(double scale) => Matrix4.identity()
    ..rotateX(_objPitch)
    ..rotateY(_objYaw)
    ..scaleByDouble(scale, scale, scale, 1);

  Iterable<Future<void>> _ambientChildren(_Placed p, double t) sync* {
    Matrix4 rotY(double a) => Matrix4.rotationY(a);
    if (p.key == SceneAssets.capsule) {
      final breathe = 1 + 0.012 * math.sin(t * 1.4);
      yield backend.setTransform(
        p.handle,
        Matrix4.diagonal3Values(breathe, breathe, breathe),
        child: 'Shell',
      );
      yield backend.setTransform(p.handle, rotY(t * 0.05), child: 'Lattice');
      yield backend.setTransform(p.handle, rotY(-t * 0.12), child: 'Seal');
      yield backend.setTransform(p.handle, rotY(t * 0.09), child: 'Particles');
      return;
    }
    if (p.key.startsWith('planet_')) {
      yield backend.setTransform(p.handle, rotY(t * 0.035), child: 'Clouds');
      yield backend.setTransform(p.handle, rotY(t * 0.06), child: 'Ring');
      yield backend.setTransform(
        p.handle,
        Matrix4.rotationY(t * 0.03)
          ..translateByDouble(0, 0.02 * math.sin(t * 0.7), 0, 1),
        child: 'Particles',
      );
      if (p.key == SceneAssets.tide) {
        yield backend.setTransform(p.handle, rotY(t * 0.22), child: 'Moon');
      }
    }
  }

  void _updateLabels() {
    final out = <SceneLabel>[];
    if (_mode == SceneMode.universe) {
      for (final g in _galaxies.values) {
        final pos = SceneLayout.galaxyPosition(g.year!);
        final s = rig.project(pos, _viewport);
        if (s == null) continue;
        out.add(
          SceneLabel(
            id: '${g.year}',
            position: s,
            radius: rig.projectedRadius(
              pos,
              SceneLayout.galaxyPickRadius,
              _viewport,
            ),
            depth: (pos - rig.eye).length,
          ),
        );
      }
    } else if (_mode == SceneMode.galaxy) {
      for (final p in _planets) {
        final s = rig.project(p.position, _viewport);
        if (s == null) continue;
        out.add(
          SceneLabel(
            id: p.memoryId!,
            position: s,
            radius: rig.projectedRadius(p.position, p.scale * 1.15, _viewport),
            depth: (p.position - rig.eye).length,
          ),
        );
      }
    }
    labels.value = out;
  }

  // ---------------------------------------------------------------- gestures
  int _pointers = 0;
  double _lastScale = 1;

  void onScaleStart(int pointerCount) {
    _pointers = pointerCount;
    _lastScale = 1;
    _lastInteraction = _t;
  }

  void onScaleUpdate({
    required Offset focalDelta,
    required double scale,
    required int pointerCount,
  }) {
    _lastInteraction = _t;
    if (_mode == SceneMode.loading || _mode == SceneMode.reveal) return;
    if (pointerCount != _pointers) {
      _pointers = pointerCount;
      _lastScale = scale;
    }
    final ds = scale / (_lastScale == 0 ? 1 : _lastScale);
    _lastScale = scale;
    if (pointerCount >= 2 && (ds - 1).abs() > 0.0005) rig.zoomBy(ds);
    if (_mode == SceneMode.planet || _mode == SceneMode.capsule) {
      final k = math.pi / math.max(1, _viewport.height) * 1.3;
      _goalObjYaw += focalDelta.dx * k;
      _goalObjPitch = (_goalObjPitch + focalDelta.dy * k).clamp(-0.65, 0.65);
      _objYawVel = 0;
    } else {
      if (_focusedId != null && focalDelta.distance > 6) clearFocus();
      rig.orbitBy(focalDelta, _viewport);
    }
  }

  void onScaleEnd(Velocity velocity, int pointerCount) {
    _lastInteraction = _t;
    if (pointerCount > 1) return;
    final v = velocity.pixelsPerSecond;
    if (_mode == SceneMode.planet || _mode == SceneMode.capsule) {
      final k = math.pi / math.max(1, _viewport.height) * 1.3;
      _objYawVel = (v.dx * k * 0.35).clamp(-3.0, 3.0);
    } else if (_mode == SceneMode.universe || _mode == SceneMode.galaxy) {
      rig.fling(v, _viewport);
    }
  }

  /// Returns what the tap hit (nearest entity whose projected disc contains it).
  SceneHit? hitTest(Offset p) {
    SceneHit? best;
    var bestDepth = double.infinity;
    for (final l in labels.value) {
      final r = math.max(l.radius * 1.1, 34.0);
      if ((l.position - p).distance <= r && l.depth < bestDepth) {
        bestDepth = l.depth;
        best = _mode == SceneMode.universe
            ? SceneHit(year: int.parse(l.id))
            : SceneHit(memoryId: l.id);
      }
    }
    return best;
  }

  // ------------------------------------------------------------ compositions
  Future<void> _hideAll() async {
    for (final g in _galaxies.values) {
      await backend.setVisible(g.handle, false);
    }
    for (final p in [..._planets, ..._rings]) {
      await backend.release(p.handle);
    }
    _planets.clear();
    _rings.clear();
    if (_hero != null) await backend.release(_hero!.handle);
    if (_revealPlanet != null) await backend.release(_revealPlanet!.handle);
    _hero = null;
    _revealPlanet = null;
    _focusedId = null;
  }

  Future<void> _composeUniverse() async {
    await _hideAll();
    for (final g in _galaxies.values) {
      await backend.setVisible(g.handle, true);
    }
    rig.bounds = const OrbitBounds(
      minDistance: 11,
      maxDistance: 32,
      minPitch: -0.45,
      maxPitch: 0.55,
      minYaw: -0.6,
      maxYaw: 0.6,
    );
    await backend.setBloom(0.1);
    _mode = SceneMode.universe;
  }

  /// Universe level. [fromYear] starts the camera near that galaxy and pulls back.
  Future<void> showUniverse({int? fromYear}) async {
    if (_mode == SceneMode.loading) return;
    await _composeUniverse();
    _activeYear = null;
    if (fromYear != null && !reducedMotion) {
      rig.jumpTo(
        target: SceneLayout.galaxyPosition(fromYear),
        yaw: 0,
        pitch: 0.05,
        distance: 11,
      );
      veil.value = 0.6;
      _animateVeil(0.6, 0, const Duration(milliseconds: 900));
    } else {
      rig.jumpTo(
        target: SceneLayout.universeTarget,
        yaw: 0,
        pitch: 0.05,
        distance: SceneLayout.universeDistance,
      );
    }
    rig.setGoal(
      target: SceneLayout.universeTarget,
      yaw: 0,
      pitch: 0.05,
      distance: SceneLayout.universeDistance,
    );
    notifyListeners();
  }

  /// Camera flight into a galaxy (the cinematic part of "enter galaxy").
  Future<void> flyIntoGalaxy(int year) async {
    if (_mode != SceneMode.universe) return;
    final dur = reducedMotion
        ? const Duration(milliseconds: 250)
        : const Duration(milliseconds: 1250);
    rig.setGoal(
      target: SceneLayout.galaxyPosition(year),
      distance: 11,
      yaw: rig.goalYaw * 0.3,
    );
    rig.stiffness = 3.2;
    await _animateVeil(0, 1, dur);
    rig.stiffness = 6;
  }

  Future<void> showGalaxy(
    int year,
    List<Memory> memories, {
    required DateTime now,
    required bool Function(Memory) evolved,
  }) async {
    if (_mode == SceneMode.loading) return;
    final previousMode = _mode;
    await _hideAll();
    _activeYear = year;
    final g = _galaxies[year]!;
    await backend.setVisible(g.handle, true);
    final sorted = [...memories]
      ..sort((a, b) => a.memoryDate.compareTo(b.memoryDate));
    for (var i = 0; i < sorted.length; i++) {
      final m = sorted[i];
      final locked = m.isLockedAt(now);
      final key = SceneLayout.assetFor(m, locked: locked, evolved: evolved(m));
      final p = _Placed(await backend.acquire(key), key)
        ..memoryId = m.id
        ..locked = locked
        ..orbit = SceneLayout.orbitFor(i, sorted.length)
        ..scale = SceneLayout.planetScale(m, locked: locked)
        ..spin = i * 1.3;
      p.position = p.orbit!.positionAt(_t);
      _planets.add(p);
      final ring = _Placed(
        await backend.acquire(SceneAssets.orbitRing),
        SceneAssets.orbitRing,
      );
      await backend.setTransform(ring.handle, p.orbit!.ringTransform());
      await backend.setVisible(ring.handle, true);
      _rings.add(ring);
      await backend.setTransform(
        p.handle,
        _planetMatrix(p.position, p.scale, p.spin),
      );
      await backend.setVisible(p.handle, true);
    }
    rig.bounds = const OrbitBounds(
      minDistance: 4.5,
      maxDistance: 30,
      minPitch: 0.12,
      maxPitch: 1.3,
    );
    _mode = SceneMode.galaxy;
    if (previousMode == SceneMode.universe && !reducedMotion) {
      rig.jumpTo(target: Vector3.zero(), yaw: 0.35, pitch: 0.75, distance: 7.5);
      veil.value = 1;
      unawaited(_animateVeil(1, 0, const Duration(milliseconds: 1100)));
    } else {
      rig.jumpTo(target: Vector3.zero(), yaw: 0.35, pitch: 0.55, distance: 16);
    }
    rig.setGoal(target: Vector3.zero(), yaw: 0.35, pitch: 0.55, distance: 16);
    await backend.setBloom(0.12);
    notifyListeners();
  }

  /// Animated camera focus toward a planet (it keeps following its orbit).
  void focusPlanet(String memoryId) {
    final p = _planets.where((e) => e.memoryId == memoryId).firstOrNull;
    if (p == null) return;
    _focusedId = memoryId;
    rig.setGoal(target: p.position, distance: 2.6 + p.scale * 3.2, pitch: 0.32);
    notifyListeners();
  }

  void clearFocus() {
    if (_focusedId == null) return;
    _focusedId = null;
    rig.setGoal(target: Vector3.zero(), distance: 16, pitch: 0.55);
    notifyListeners();
  }

  Future<void> _showSingle(
    String key, {
    required SceneMode mode,
    double scale = 1,
  }) async {
    await _hideAll();
    final h = _Placed(await backend.acquire(key), key)..scale = scale;
    await backend.setTransform(h.handle, _heroMatrix(scale));
    await backend.setVisible(h.handle, true);
    _hero = h;
    _mode = mode;
    rig.bounds = const OrbitBounds(
      minDistance: 2.9,
      maxDistance: 9.5,
      minPitch: -0.2,
      maxPitch: 0.6,
    );
    final startDist = reducedMotion
        ? SceneLayout.planetDistance
        : SceneLayout.planetDistance + 3.2;
    rig.jumpTo(
      target: SceneLayout.planetTarget,
      yaw: 0,
      pitch: 0.16,
      distance: startDist,
    );
    rig.setGoal(distance: SceneLayout.planetDistance);
    _goalObjPitch = _objPitch = 0.05;
    _goalObjYaw = _objYaw = 0.45;
    _objYawVel = 0;
    notifyListeners();
  }

  Future<void> showPlanet(Memory m, {required bool evolved}) async {
    if (_mode == SceneMode.loading) return;
    await _showSingle(
      SceneLayout.assetFor(m, locked: false, evolved: evolved),
      mode: SceneMode.planet,
    );
    await backend.setBloom(0.12);
    await backend.setKeyLight(
      intensityScale: 1,
      color: Vector3(1.0, 0.86, 0.72),
    );
  }

  Future<void> showCapsule(Memory m) async {
    if (_mode == SceneMode.loading) return;
    await _showSingle(SceneAssets.capsule, mode: SceneMode.capsule);
    await _resetCapsuleMaterials(_hero!);
    await backend.setBloom(0.14);
    await backend.setKeyLight(
      intensityScale: 0.8,
      color: Vector3(0.85, 0.88, 0.9),
    );
  }

  // ------------------------------------------------------------------ reveal
  bool _skip = false;

  /// Cinematic sealed-capsule -> planet transformation. Completes when done
  /// or when [skipReveal] is called.
  Future<void> playReveal(Memory m) async {
    if (_mode == SceneMode.loading) return;
    if (_hero?.key != SceneAssets.capsule) await showCapsule(m);
    final capsule = _hero!;
    _mode = SceneMode.reveal;
    _skip = false;
    final planetKey = SceneLayout.assetFor(m, locked: false);
    final planet = _Placed(await backend.acquire(planetKey), planetKey)
      ..scale = 0.0001;
    _revealPlanet = planet;
    await backend.setTransform(planet.handle, _heroMatrix(planet.scale));
    await backend.setVisible(planet.handle, true);
    notifyListeners();

    // Progress follows scene time (advanced by the frame ticker), so the
    // sequence pauses with the app and is deterministic under test.
    final total = reducedMotion ? 0.9 : 5.2;
    final start = _t;
    final startYaw = rig.yaw;
    while (true) {
      final p = _skip ? 1.0 : math.min(1.0, (_t - start) / total);
      if (_disposed) return;
      revealProgress.value = p;
      await _applyReveal(capsule, planet, p, startYaw);
      if (p >= 1) break;
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    // Hand over: the planet becomes the hero, the capsule returns to the pool.
    await backend.setVisible(capsule.handle, false);
    await _resetCapsuleMaterials(capsule);
    await backend.release(capsule.handle);
    planet.scale = 1;
    _hero = planet;
    _revealPlanet = null;
    _mode = SceneMode.planet;
    rig.setGoal(distance: SceneLayout.planetDistance, pitch: 0.16);
    await backend.setBloom(0.12);
    await backend.setKeyLight(
      intensityScale: 1,
      color: Vector3(1.0, 0.86, 0.72),
    );
    revealProgress.value = 1;
    notifyListeners();
  }

  void skipReveal() => _skip = true;

  static double _seg(double p, double a, double b) =>
      ((p - a) / (b - a)).clamp(0.0, 1.0);
  static double _ease(double x) => x * x * (3 - 2 * x);

  static final _shellColor = Vector4(0.521, 0.672, 0.644, 0.30);
  static final _latticeEmissive = Vector3(0.784, 0.558, 0.423);

  Future<void> _resetCapsuleMaterials(_Placed c) async {
    await backend.setMaterial(c.handle, 'Shell', baseColor: _shellColor);
    await backend.setMaterial(
      c.handle,
      'LatticeMesh',
      emissive: _latticeEmissive,
    );
    await backend.setTransform(c.handle, Matrix4.identity(), child: 'Core');
    await backend.setTransform(c.handle, Matrix4.identity(), child: 'Lattice');
    await backend.setTransform(c.handle, Matrix4.identity(), child: 'Seal');
  }

  Future<void> _applyReveal(
    _Placed c,
    _Placed planet,
    double p,
    double startYaw,
  ) async {
    final anticipation = _ease(_seg(p, 0.0, 0.28));
    final dissolve = _ease(_seg(p, 0.25, 0.58));
    final grow = _ease(_seg(p, 0.38, 0.78));
    final settle = _ease(_seg(p, 0.55, 1.0));
    // Lattice brightens, then fades away with the shell.
    final glow = 1 + anticipation * 1.8 - dissolve * 2.8;
    await backend.setMaterial(
      c.handle,
      'LatticeMesh',
      emissive: _latticeEmissive * math.max(0.0, glow),
    );
    await backend.setMaterial(
      c.handle,
      'Shell',
      baseColor: Vector4(
        _shellColor.x,
        _shellColor.y,
        _shellColor.z,
        _shellColor.w * (1 - dissolve),
      ),
    );
    final open = 1 + dissolve * 0.65;
    await backend.setTransform(
      c.handle,
      Matrix4.diagonal3Values(open, open, open),
      child: 'Lattice',
    );
    await backend.setTransform(
      c.handle,
      Matrix4.rotationY(_t * (0.12 + anticipation * 2.5))
        ..scaleByDouble(open * 1.05, 1, open * 1.05, 1),
      child: 'Seal',
    );
    final core = math.max(0.0001, 1 - grow);
    await backend.setTransform(
      c.handle,
      Matrix4.diagonal3Values(core, core, core),
      child: 'Core',
    );
    planet.scale = math.max(0.0001, 0.6 * grow + 0.4 * grow * grow);
    // Lighting: dim during anticipation, then warm and brighter as it blooms.
    final light =
        0.8 -
        anticipation * 0.2 +
        settle * 0.6 -
        _ease(_seg(p, 0.85, 1.0)) * 0.2;
    final warm =
        Vector3(0.85, 0.88, 0.9) * (1 - settle) +
        Vector3(1.0, 0.82, 0.66) * settle;
    await backend.setKeyLight(intensityScale: light, color: warm);
    await backend.setBloom(0.12 + 0.22 * math.sin(math.pi * _seg(p, 0.3, 0.9)));
    if (!reducedMotion) {
      // Camera: lean in, then pull back and sweep around the new world.
      final dist =
          SceneLayout.planetDistance + 0.3 - anticipation * 1.2 + settle * 1.0;
      rig.setGoal(
        distance: dist,
        yaw: startYaw + settle * 0.7,
        pitch: 0.12 + settle * 0.1,
      );
    }
  }

  // ------------------------------------------------------------ rendering
  Future<void> setActive(bool active) => backend.setRendering(active);

  Future<void> _animateVeil(double from, double to, Duration d) async {
    final start = _t;
    final total = d.inMicroseconds / 1e6;
    var guard = 0;
    while (_t - start < total && guard++ < 600) {
      final x = (_t - start) / total;
      if (_disposed) return;
      veil.value = from + (to - from) * _ease(x.clamp(0.0, 1.0));
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    if (!_disposed) veil.value = to;
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    veil.dispose();
    labels.dispose();
    revealProgress.dispose();
    unawaited(backend.dispose());
    super.dispose();
  }
}
