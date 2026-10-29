import 'package:flutter/services.dart';

import '../../../core/platform/platform_failure.dart';

class LocationStatus {
  const LocationStatus({
    required this.permission,
    required this.serviceAvailable,
    required this.gpsAvailable,
    required this.gpsEnabled,
    required this.networkAvailable,
    required this.networkEnabled,
    required this.locationEnabled,
  });

  factory LocationStatus.fromMap(Map<Object?, Object?> m) => LocationStatus(
    permission: m['permission'] as bool? ?? false,
    serviceAvailable: m['serviceAvailable'] as bool? ?? false,
    gpsAvailable: m['gpsAvailable'] as bool? ?? false,
    gpsEnabled: m['gpsEnabled'] as bool? ?? false,
    networkAvailable: m['networkAvailable'] as bool? ?? false,
    networkEnabled: m['networkEnabled'] as bool? ?? false,
    locationEnabled: m['locationEnabled'] as bool? ?? false,
  );

  final bool permission;
  final bool serviceAvailable;
  final bool gpsAvailable;
  final bool gpsEnabled;
  final bool networkAvailable;
  final bool networkEnabled;
  final bool locationEnabled;
}

class LocationFix {
  const LocationFix({
    required this.provider,
    required this.lat,
    required this.lon,
    required this.fixTime,
    this.accuracy,
    this.speed,
    this.speedAccuracy,
    this.bearing,
  });

  /// [receivedAt] is the monotonic app clock when the event arrived; the native age is subtracted from it.
  factory LocationFix.fromMap(Map<Object?, Object?> m, Duration receivedAt) =>
      LocationFix(
        provider: m['provider'] as String? ?? 'unknown',
        lat: (m['lat']! as num).toDouble(),
        lon: (m['lon']! as num).toDouble(),
        accuracy: (m['accuracy'] as num?)?.toDouble(),
        speed: (m['speed'] as num?)?.toDouble(),
        speedAccuracy: (m['speedAccuracy'] as num?)?.toDouble(),
        bearing: (m['bearing'] as num?)?.toDouble(),
        fixTime:
            receivedAt -
            Duration(milliseconds: (m['ageMs'] as num? ?? 0).toInt()),
      );

  final String provider;
  final double lat;
  final double lon;
  final double? accuracy;

  /// Metres per second, as reported by Android. Never derived from position deltas.
  final double? speed;
  final double? speedAccuracy;
  final double? bearing;

  /// Monotonic time of the fix (see [monotonicNow]). Immune to wall-clock changes.
  final Duration fixTime;

  bool get isGps => provider == 'gps';
}

final _clock = Stopwatch()..start();

/// Monotonic clock shared by everything that measures data freshness.
Duration monotonicNow() => _clock.elapsed;

abstract interface class LocationRepository {
  Future<LocationStatus> getStatus();

  /// Emits [LocationStatus] and [LocationFix] objects. Native updates run only while subscribed.
  Stream<Object> events();
  Future<void> restart();
}

class ChannelLocationRepository implements LocationRepository {
  static const _channel = MethodChannel('swiftdrive/location');
  static const _events = EventChannel('swiftdrive/location/events');

  @override
  Future<LocationStatus> getStatus() => guardPlatform(
    'location',
    () async => LocationStatus.fromMap(
      (await _channel.invokeMapMethod<Object?, Object?>('getStatus'))!,
    ),
  );

  @override
  Stream<Object> events() => _events.receiveBroadcastStream().map((e) {
    final m = e as Map<Object?, Object?>;
    return m['type'] == 'fix'
        ? LocationFix.fromMap(m, monotonicNow())
        : LocationStatus.fromMap(m);
  });

  @override
  Future<void> restart() =>
      guardPlatform('location', () => _channel.invokeMethod('restart'));
}
