import 'dart:math' as math;

import '../data/navigation_models.dart';

const _earthRadius = 6371000.0;

double _rad(double deg) => deg * math.pi / 180;

double haversine(GeoPoint a, GeoPoint b) {
  final dLat = _rad(b.lat - a.lat);
  final dLon = _rad(b.lon - a.lon);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.lat)) *
          math.cos(_rad(b.lat)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * _earthRadius * math.asin(math.sqrt(h));
}

class RouteProgress {
  const RouteProgress({
    required this.offRouteMeters,
    required this.remainingMeters,
    required this.remainingSeconds,
    this.nextStep,
    this.nextStepIndex,
    this.metersToNextStep,
  });

  final double offRouteMeters;
  final double remainingMeters;
  final double remainingSeconds;
  final RouteStep? nextStep;
  final int? nextStepIndex;
  final double? metersToNextStep;
}

/// Pre-computed route for cheap per-fix progress. Local equirectangular projection is accurate to well
/// under a metre at segment lengths found in road geometry.
class RouteTracker {
  RouteTracker(this.route) {
    final g = route.geometry;
    _cumulative = List.filled(g.length, 0);
    for (var i = 1; i < g.length; i++) {
      _cumulative[i] = _cumulative[i - 1] + haversine(g[i - 1], g[i]);
    }
    _stepAlong = [for (final s in route.steps) _project(s.location).$2];
  }

  final RouteResult route;
  late final List<double> _cumulative;
  late final List<double> _stepAlong;

  double get totalMeters => _cumulative.isEmpty ? 0 : _cumulative.last;

  /// Returns (distance from route, distance along route) of the nearest point on the polyline.
  (double, double) _project(GeoPoint p) {
    final g = route.geometry;
    if (g.length < 2) {
      return (g.isEmpty ? double.infinity : haversine(p, g.first), 0);
    }
    final cosLat = math.cos(_rad(p.lat));
    var bestDist = double.infinity;
    var bestAlong = 0.0;
    for (var i = 0; i < g.length - 1; i++) {
      final a = g[i];
      final b = g[i + 1];
      final ax = (a.lon - p.lon) * cosLat, ay = a.lat - p.lat;
      final bx = (b.lon - p.lon) * cosLat, by = b.lat - p.lat;
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
      final px = ax + t * dx, py = ay + t * dy;
      final d = _rad(math.sqrt(px * px + py * py)) * _earthRadius;
      if (d < bestDist) {
        bestDist = d;
        bestAlong = _cumulative[i] + t * (_cumulative[i + 1] - _cumulative[i]);
      }
    }
    return (bestDist, bestAlong);
  }

  RouteProgress progress(GeoPoint position) {
    final (off, along) = _project(position);
    final remaining = math.max(0.0, totalMeters - along);
    final seconds = totalMeters == 0
        ? 0.0
        : route.durationSeconds * remaining / totalMeters;
    int? next;
    for (var i = 0; i < _stepAlong.length; i++) {
      // A maneuver counts as passed once we are 10 m beyond it.
      if (_stepAlong[i] > along - 10 && route.steps[i].type != 'depart') {
        next = i;
        break;
      }
    }
    return RouteProgress(
      offRouteMeters: off,
      remainingMeters: remaining,
      remainingSeconds: seconds,
      nextStepIndex: next,
      nextStep: next == null ? null : route.steps[next],
      metersToNextStep: next == null
          ? null
          : math.max(0.0, _stepAlong[next] - along),
    );
  }
}
