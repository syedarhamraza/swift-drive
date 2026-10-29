import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Development-only metrics for the diagnostics screen. Nothing is collected in release builds.
abstract final class PerfMetrics {
  static final _recent = <FrameTiming>[];
  static Duration? mapInitTime;
  static Duration? firstFrameTime;

  static void install() {
    if (kReleaseMode) return;
    SchedulerBinding.instance.addTimingsCallback((timings) {
      _recent.addAll(timings);
      if (_recent.length > 240) _recent.removeRange(0, _recent.length - 240);
    });
  }

  /// (frames, average build ms, average raster ms, frames over 16 ms).
  static (int, double, double, int) summary() {
    if (_recent.isEmpty) return (0, 0, 0, 0);
    double ms(Duration d) => d.inMicroseconds / 1000;
    final build =
        _recent.map((t) => ms(t.buildDuration)).reduce((a, b) => a + b) /
        _recent.length;
    final raster =
        _recent.map((t) => ms(t.rasterDuration)).reduce((a, b) => a + b) /
        _recent.length;
    final slow = _recent.where((t) => ms(t.totalSpan) > 16.7).length;
    return (_recent.length, build, raster, slow);
  }
}
