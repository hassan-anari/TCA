import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import '../data/models.dart';
import 'scene_backend.dart';

/// Art-directed spatial layout. Pure functions so it can be unit tested.
abstract final class SceneLayout {
  // ---------------------------------------------------------------- universe
  static final universeTarget = Vector3(0, 0.2, -1.5);
  static const universeDistance = 21.0;
  static const universeGalaxyScale = 0.62;

  static Vector3 galaxyPosition(int year) => switch (year) {
    2024 => Vector3(-1.5, -5.4, 0.6),
    2025 => Vector3(1.9, 0.1, -1.6),
    _ => Vector3(-1.3, 5.7, -3.6),
  };

  /// Tilt (radians about X) and roll (about Z) give each galaxy its own pose.
  static (double tilt, double roll) galaxyPose(int year) => switch (year) {
    2024 => (1.02, 0.18),
    2025 => (0.92, -0.22),
    _ => (1.12, 0.35),
  };

  static double galaxySpinSpeed(int year) => switch (year) {
    2024 => 0.05,
    2025 => -0.035,
    _ => 0.028,
  };

  static Matrix4 universeGalaxyTransform(int year, double t) {
    final (tilt, roll) = galaxyPose(year);
    return Matrix4.identity()
      ..translateByVector3(galaxyPosition(year))
      ..rotateX(tilt)
      ..rotateZ(roll)
      ..rotateY(t * galaxySpinSpeed(year))
      ..scaleByDouble(
        universeGalaxyScale,
        universeGalaxyScale,
        universeGalaxyScale,
        1,
      );
  }

  /// Picking radius of a galaxy in universe space.
  static const galaxyPickRadius = 4.0 * universeGalaxyScale;

  // ------------------------------------------------------------------ galaxy
  static const galaxyBackdropScale = 1.9;

  static Matrix4 galaxyBackdropTransform(int year, double t) =>
      Matrix4.identity()
        ..translateByDouble(0, -0.6, 0, 1)
        ..rotateX(0.04)
        ..rotateY(t * galaxySpinSpeed(year) * 0.5)
        ..scaleByDouble(
          galaxyBackdropScale,
          galaxyBackdropScale,
          galaxyBackdropScale,
          1,
        );

  static String assetFor(
    Memory m, {
    required bool locked,
    bool evolved = false,
  }) {
    if (locked) return SceneAssets.capsule;
    return switch (m.world) {
      WorldStyle.bloom =>
        evolved ? SceneAssets.bloomEvolved : SceneAssets.bloom,
      WorldStyle.tide => SceneAssets.tide,
      WorldStyle.dune => SceneAssets.dune,
      WorldStyle.frost => SceneAssets.frost,
      WorldStyle.grove => SceneAssets.grove,
      WorldStyle.ember => SceneAssets.ember,
    };
  }

  static double planetScale(Memory m, {required bool locked}) {
    if (locked) return 0.62;
    return m.world == WorldStyle.bloom ? 0.92 : 0.66;
  }

  /// Orbit of the i-th memory in a galaxy (organic, golden-angle spacing).
  static Orbit orbitFor(int index, int count) {
    final r = 3.4 + index * 1.35;
    final phase = index * 2.39996 + 0.6;
    final height = math.sin(index * 1.7 + 0.4) * 0.7;
    final speed = 0.09 / math.sqrt(r);
    return Orbit(radius: r, phase: phase, height: height, speed: speed);
  }

  // ------------------------------------------------------------------ planet
  static final planetTarget = Vector3(0, 0.22, 0);
  static const planetDistance = 5.4;
}

class Orbit {
  const Orbit({
    required this.radius,
    required this.phase,
    required this.height,
    required this.speed,
  });
  final double radius;
  final double phase;
  final double height;
  final double speed;

  Vector3 positionAt(double t) {
    final a = phase + t * speed;
    return Vector3(math.cos(a) * radius, height, math.sin(a) * radius);
  }

  Matrix4 ringTransform() => Matrix4.identity()
    ..translateByDouble(0, height, 0, 1)
    ..scaleByDouble(radius, radius, radius, 1);
}
