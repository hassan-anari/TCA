import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'scene_backend.dart';

/// Adaptive rendering quality: watches Flutter frame timings and steps the
/// renderer down (bloom/FXAA/render quality) if frames stay slow, and back
/// up when there is headroom. Heuristic - measures the Flutter pipeline that
/// composites the Filament texture, not the GPU directly.
class QualityGovernor {
  QualityGovernor(this.backend);

  final SceneBackend backend;
  final List<double> _window = [];
  QualityTier _tier = QualityTier.high;
  DateTime _lastChange = DateTime.fromMillisecondsSinceEpoch(0);

  static final ValueNotifier<double> uiFps = ValueNotifier(0);
  static final ValueNotifier<QualityTier> tier = ValueNotifier(
    QualityTier.high,
  );

  void start() => SchedulerBinding.instance.addTimingsCallback(_onTimings);
  void stop() => SchedulerBinding.instance.removeTimingsCallback(_onTimings);

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _window.add(t.totalSpan.inMicroseconds / 1000.0);
    }
    if (_window.length < 90) return;
    final recent = _window.sublist(_window.length - 90);
    _window.clear();
    final avg = recent.reduce((a, b) => a + b) / recent.length;
    uiFps.value = 1000 / avg.clamp(1000 / 120, 1000);
    final now = DateTime.now();
    if (now.difference(_lastChange).inSeconds < 4) return;
    QualityTier next = _tier;
    if (avg > 24 && _tier != QualityTier.low) {
      next = QualityTier.values[_tier.index + 1];
    } else if (avg < 12 && _tier != QualityTier.high) {
      next = QualityTier.values[_tier.index - 1];
    }
    if (next != _tier) {
      _tier = next;
      tier.value = next;
      _lastChange = now;
      backend.setQuality(next);
    }
  }
}
