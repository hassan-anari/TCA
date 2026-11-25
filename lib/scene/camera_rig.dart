import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:vector_math/vector_math_64.dart';

/// Limits that keep the camera inside an intentional, art-directed volume.
class OrbitBounds {
  const OrbitBounds({
    required this.minDistance,
    required this.maxDistance,
    this.minPitch = -1.2,
    this.maxPitch = 1.2,
    this.minYaw = -double.infinity,
    this.maxYaw = double.infinity,
  });

  final double minDistance;
  final double maxDistance;
  final double minPitch;
  final double maxPitch;
  final double minYaw;
  final double maxYaw;
}

/// Spherical orbit camera with critically-damped smoothing toward a goal.
///
/// Pure Dart (no rendering dependency) so its behaviour is unit tested.
class CameraRig {
  CameraRig({
    Vector3? target,
    this.yaw = 0,
    this.pitch = 0.3,
    this.distance = 10,
    this.fovY = 45,
    this.bounds = const OrbitBounds(minDistance: 2, maxDistance: 40),
  }) : target = target ?? Vector3.zero(),
       goalTarget = (target ?? Vector3.zero()).clone(),
       goalYaw = yaw,
       goalPitch = pitch,
       goalDistance = distance;

  Vector3 target;
  double yaw;
  double pitch;
  double distance;
  double fovY;
  OrbitBounds bounds;

  Vector3 goalTarget;
  double goalYaw;
  double goalPitch;
  double goalDistance;

  /// Higher = snappier. ~6 feels calm and cinematic.
  double stiffness = 6.0;

  /// Angular velocity carried after a fling (radians / second).
  double _yawVel = 0;
  double _pitchVel = 0;

  Vector3 get up => Vector3(0, 1, 0);

  Vector3 get eye {
    final cp = math.cos(pitch);
    return target +
        Vector3(math.sin(yaw) * cp, math.sin(pitch), math.cos(yaw) * cp) *
            distance;
  }

  void setGoal({
    Vector3? target,
    double? yaw,
    double? pitch,
    double? distance,
  }) {
    if (target != null) goalTarget = target.clone();
    if (yaw != null) goalYaw = yaw;
    if (pitch != null) goalPitch = pitch;
    if (distance != null) goalDistance = distance;
    _clampGoal();
  }

  /// Teleport (no interpolation), e.g. when a new spatial level starts.
  void jumpTo({Vector3? target, double? yaw, double? pitch, double? distance}) {
    setGoal(target: target, yaw: yaw, pitch: pitch, distance: distance);
    this.target = goalTarget.clone();
    this.yaw = goalYaw;
    this.pitch = goalPitch;
    this.distance = goalDistance;
    _yawVel = 0;
    _pitchVel = 0;
  }

  /// Drag in logical pixels relative to the viewport height.
  void orbitBy(Offset delta, Size viewport) {
    final k = math.pi / math.max(viewport.height, 1) * 1.1;
    goalYaw -= delta.dx * k;
    goalPitch += delta.dy * k;
    _clampGoal();
  }

  void zoomBy(double scaleFactor) {
    if (scaleFactor <= 0) return;
    goalDistance /= scaleFactor;
    _clampGoal();
  }

  void fling(Offset velocityPxPerSec, Size viewport) {
    final k = math.pi / math.max(viewport.height, 1) * 1.1;
    _yawVel = -velocityPxPerSec.dx * k * 0.35;
    _pitchVel = velocityPxPerSec.dy * k * 0.35;
  }

  void _clampGoal() {
    goalPitch = goalPitch.clamp(bounds.minPitch, bounds.maxPitch);
    goalYaw = goalYaw.clamp(bounds.minYaw, bounds.maxYaw);
    goalDistance = goalDistance.clamp(bounds.minDistance, bounds.maxDistance);
  }

  /// Advance smoothing by [dt] seconds. Returns true while still moving.
  bool update(double dt) {
    if (dt <= 0) return false;
    dt = math.min(dt, 0.05);
    if (_yawVel.abs() > 1e-4 || _pitchVel.abs() > 1e-4) {
      goalYaw += _yawVel * dt;
      goalPitch += _pitchVel * dt;
      final decay = math.exp(-3.5 * dt);
      _yawVel *= decay;
      _pitchVel *= decay;
      _clampGoal();
    }
    final a = 1 - math.exp(-stiffness * dt);
    yaw += (goalYaw - yaw) * a;
    pitch += (goalPitch - pitch) * a;
    distance += (goalDistance - distance) * a;
    target += (goalTarget - target) * a;
    return (goalYaw - yaw).abs() > 1e-4 ||
        (goalPitch - pitch).abs() > 1e-4 ||
        (goalDistance - distance).abs() > 1e-3 ||
        (goalTarget - target).length > 1e-3;
  }

  Matrix4 viewMatrix() => makeViewMatrix(eye, target, up);

  Matrix4 projectionMatrix(
    double aspect, {
    double near = 0.1,
    double far = 400,
  }) => makePerspectiveMatrix(fovY * math.pi / 180, aspect, near, far);

  /// Projects a world position into viewport pixels. Returns null when the
  /// point is behind the camera.
  Offset? project(Vector3 world, Size viewport) {
    final aspect = viewport.width / math.max(viewport.height, 1);
    final clip =
        projectionMatrix(aspect) *
        viewMatrix() *
        Vector4(world.x, world.y, world.z, 1);
    if (clip.w <= 0) return null;
    final ndcX = clip.x / clip.w;
    final ndcY = clip.y / clip.w;
    return Offset(
      (ndcX + 1) * 0.5 * viewport.width,
      (1 - ndcY) * 0.5 * viewport.height,
    );
  }

  /// Approximate on-screen radius (pixels) of a sphere of [radius] at [world].
  double projectedRadius(Vector3 world, double radius, Size viewport) {
    final d = (world - eye).length;
    if (d <= 1e-3) return viewport.height;
    final f = 1 / math.tan(fovY * math.pi / 360);
    return radius / d * f * viewport.height * 0.5;
  }
}
