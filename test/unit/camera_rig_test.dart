import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:memoria/scene/camera_rig.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('zoom is clamped to bounds', () {
    final rig = CameraRig(
      distance: 10,
      bounds: const OrbitBounds(minDistance: 4, maxDistance: 20),
    );
    rig.zoomBy(100);
    expect(rig.goalDistance, 4);
    rig.zoomBy(0.001);
    expect(rig.goalDistance, 20);
  });

  test('pitch is clamped and yaw follows drag direction', () {
    final rig = CameraRig(
      bounds: const OrbitBounds(
        minDistance: 1,
        maxDistance: 50,
        minPitch: -0.2,
        maxPitch: 0.4,
      ),
    );
    rig.orbitBy(const Offset(0, 5000), const Size(400, 800));
    expect(rig.goalPitch, 0.4);
    final before = rig.goalYaw;
    rig.orbitBy(const Offset(100, 0), const Size(400, 800));
    expect(rig.goalYaw, lessThan(before));
  });

  test('smoothing converges to the goal without overshoot', () {
    final rig = CameraRig(distance: 10);
    rig.setGoal(distance: 5, target: Vector3(1, 2, 3));
    var last = rig.distance;
    for (var i = 0; i < 300; i++) {
      rig.update(1 / 60);
      expect(rig.distance, lessThanOrEqualTo(last + 1e-9));
      last = rig.distance;
    }
    expect(rig.distance, closeTo(5, 1e-3));
    expect((rig.target - Vector3(1, 2, 3)).length, lessThan(1e-3));
  });

  test('projection puts the target at the viewport centre', () {
    final rig = CameraRig(
      target: Vector3(0, 0, 0),
      distance: 10,
      pitch: 0.2,
      yaw: 0.7,
    );
    final p = rig.project(Vector3.zero(), const Size(400, 800))!;
    expect(p.dx, closeTo(200, 1e-6));
    expect(p.dy, closeTo(400, 1e-6));
  });

  test('points behind the camera are not projected', () {
    final rig = CameraRig(
      target: Vector3(0, 0, 0),
      distance: 10,
      pitch: 0,
      yaw: 0,
    );
    expect(rig.project(Vector3(0, 0, 30), const Size(400, 800)), isNull);
  });

  test('closer objects have larger projected radius', () {
    final rig = CameraRig(distance: 10);
    final near = rig.projectedRadius(Vector3(0, 0, 5), 1, const Size(400, 800));
    final far = rig.projectedRadius(Vector3(0, 0, -5), 1, const Size(400, 800));
    expect(near, greaterThan(far));
  });
}
