import '../../../core/storage/settings.dart';
import '../data/location_repository.dart';

enum SpeedStatus {
  valid,
  acquiring,
  poorAccuracy,
  stale,
  gpsDisabled,
  permissionDenied,
  unavailable,
}

class SpeedState {
  const SpeedState(this.status, [this.metersPerSecond]);

  final SpeedStatus status;

  /// Only set when [status] is [SpeedStatus.valid]. Stale speed is never exposed as live.
  final double? metersPerSecond;

  @override
  bool operator ==(Object other) =>
      other is SpeedState &&
      other.status == status &&
      other.metersPerSecond == metersPerSecond;

  @override
  int get hashCode => Object.hash(status, metersPerSecond);
}

double convertSpeed(double metersPerSecond, SpeedUnit unit) =>
    unit == SpeedUnit.kmh
    ? metersPerSecond * 3.6
    : metersPerSecond * 2.2369362920544;

/// Turns raw GPS fixes into a displayable speed. Uses Android's Doppler-based Location speed only;
/// network fixes are ignored. Light EMA smoothing keeps latency to roughly one fix.
class SpeedEstimator {
  static const maxAge = Duration(seconds: 3);
  static const maxSpeedAccuracy = 2.0; // m/s
  static const maxPositionAccuracy = 50.0; // m
  static const alpha = 0.5;

  LocationFix? _last;
  double? _smoothed;

  void addFix(LocationFix fix) {
    if (!fix.isGps) return;
    _last = fix;
    final s = fix.speed;
    if (s == null || !_trustworthy(fix)) {
      _smoothed = null;
      return;
    }
    final prev = _smoothed;
    _smoothed = prev == null ? s : alpha * s + (1 - alpha) * prev;
  }

  bool _trustworthy(LocationFix f) =>
      (f.accuracy == null || f.accuracy! <= maxPositionAccuracy) &&
      (f.speedAccuracy == null || f.speedAccuracy! <= maxSpeedAccuracy);

  SpeedState evaluate(LocationStatus? status, Duration now) {
    if (status == null) return const SpeedState(SpeedStatus.acquiring);
    if (!status.serviceAvailable || !status.gpsAvailable) {
      return const SpeedState(SpeedStatus.unavailable);
    }
    if (!status.permission) {
      return const SpeedState(SpeedStatus.permissionDenied);
    }
    if (!status.gpsEnabled) return const SpeedState(SpeedStatus.gpsDisabled);
    final last = _last;
    if (last == null) return const SpeedState(SpeedStatus.acquiring);
    if (now - last.fixTime > maxAge) {
      _smoothed = null;
      return const SpeedState(SpeedStatus.stale);
    }
    if (last.speed == null) return const SpeedState(SpeedStatus.acquiring);
    if (!_trustworthy(last)) return const SpeedState(SpeedStatus.poorAccuracy);
    return SpeedState(SpeedStatus.valid, _smoothed);
  }
}
