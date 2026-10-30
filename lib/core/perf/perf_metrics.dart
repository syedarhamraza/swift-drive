import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Development-only metrics for the diagnostics screen. Nothing is collected in release builds.
abstract final class PerfMetrics {
  static final _recent = <FrameTiming>[];
  static Duration? mapInitTime;
  static Duration? firstFrameTime;
  static int _framesSinceReport = 0;

  /// Frames rendered in each of the last six 10-second windows, newest last.
  static final framesPer10s = <int>[];

  static void install() {
    if (kReleaseMode) return;
    SchedulerBinding.instance.addTimingsCallback((timings) {
      _framesSinceReport += timings.length;
      _recent.addAll(timings);
      if (_recent.length > 240) _recent.removeRange(0, _recent.length - 240);
    });
    // Console only (not the diagnostic log): frames per 10 s shows what an idle dashboard costs.
    Timer.periodic(const Duration(seconds: 10), (_) {
      debugPrint('[perf] $_framesSinceReport frames in 10 s');
      framesPer10s.add(_framesSinceReport);
      if (framesPer10s.length > 6) framesPer10s.removeAt(0);
      _framesSinceReport = 0;
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
