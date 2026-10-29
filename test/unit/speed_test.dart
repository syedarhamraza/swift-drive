import 'package:flutter_test/flutter_test.dart';
import 'package:swiftdrive/core/storage/settings.dart';
import 'package:swiftdrive/features/location/data/location_repository.dart';
import 'package:swiftdrive/features/location/domain/speed.dart';

import '../fakes/fakes.dart';

LocationFix gps(
  Duration at, {
  double? speed = 10,
  double? speedAcc = 0.5,
  double? acc = 5,
  String provider = 'gps',
}) => LocationFix(
  provider: provider,
  lat: 33.6,
  lon: 73.0,
  fixTime: at,
  speed: speed,
  speedAccuracy: speedAcc,
  accuracy: acc,
);

void main() {
  const t0 = Duration(seconds: 100);

  test('valid GPS speed is smoothed with EMA', () {
    final e = SpeedEstimator()..addFix(gps(t0, speed: 10));
    expect(e.evaluate(okStatus, t0), const SpeedState(SpeedStatus.valid, 10));
    e.addFix(gps(t0 + const Duration(seconds: 1), speed: 20));
    expect(
      e.evaluate(okStatus, t0 + const Duration(seconds: 1)).metersPerSecond,
      15,
    );
  });

  test('speed older than 3 s is stale and never shown', () {
    final e = SpeedEstimator()..addFix(gps(t0));
    final s = e.evaluate(okStatus, t0 + const Duration(seconds: 4));
    expect(s.status, SpeedStatus.stale);
    expect(s.metersPerSecond, isNull);
  });

  test('network fixes are ignored for speed', () {
    final e = SpeedEstimator()..addFix(gps(t0, provider: 'network'));
    expect(e.evaluate(okStatus, t0).status, SpeedStatus.acquiring);
  });

  test('poor speed or position accuracy is flagged', () {
    expect(
      (SpeedEstimator()..addFix(gps(t0, speedAcc: 3)))
          .evaluate(okStatus, t0)
          .status,
      SpeedStatus.poorAccuracy,
    );
    expect(
      (SpeedEstimator()..addFix(gps(t0, acc: 80)))
          .evaluate(okStatus, t0)
          .status,
      SpeedStatus.poorAccuracy,
    );
  });

  test('fix without speed keeps acquiring', () {
    expect(
      (SpeedEstimator()..addFix(gps(t0, speed: null)))
          .evaluate(okStatus, t0)
          .status,
      SpeedStatus.acquiring,
    );
  });

  test('status gates come before fixes', () {
    final e = SpeedEstimator()..addFix(gps(t0));
    LocationStatus st({
      bool perm = true,
      bool gpsAvail = true,
      bool gpsOn = true,
    }) => LocationStatus(
      permission: perm,
      serviceAvailable: true,
      gpsAvailable: gpsAvail,
      gpsEnabled: gpsOn,
      networkAvailable: true,
      networkEnabled: true,
      locationEnabled: gpsOn,
    );
    expect(e.evaluate(null, t0).status, SpeedStatus.acquiring);
    expect(e.evaluate(st(gpsAvail: false), t0).status, SpeedStatus.unavailable);
    expect(
      e.evaluate(st(perm: false), t0).status,
      SpeedStatus.permissionDenied,
    );
    expect(e.evaluate(st(gpsOn: false), t0).status, SpeedStatus.gpsDisabled);
  });

  test('unit conversion', () {
    expect(convertSpeed(10, SpeedUnit.kmh), closeTo(36, 1e-9));
    expect(convertSpeed(10, SpeedUnit.mph), closeTo(22.369, 1e-3));
  });

  test('LocationFix.fromMap subtracts native age from receipt time', () {
    final f = LocationFix.fromMap({
      'provider': 'gps',
      'lat': 1,
      'lon': 2,
      'ageMs': 500,
    }, const Duration(seconds: 10));
    expect(f.fixTime, const Duration(milliseconds: 9500));
    expect(f.isGps, isTrue);
  });
}
