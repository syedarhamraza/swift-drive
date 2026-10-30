import 'package:flutter/services.dart';

enum NetworkKind { wifi, cellular, ethernet, other, none }

/// Phone or head-unit status shown on the rail (the status bar may be hidden in full screen).
class DeviceStatus {
  const DeviceStatus({
    this.battery,
    this.charging = false,
    this.network = NetworkKind.none,
  });

  factory DeviceStatus.fromMap(Map<Object?, Object?> m) => DeviceStatus(
    battery: m['battery'] as int?,
    charging: m['charging'] as bool? ?? false,
    network: NetworkKind.values.asNameMap()[m['network']] ?? NetworkKind.none,
  );

  /// Percent, or null when the device has no battery (most head units).
  final int? battery;
  final bool charging;
  final NetworkKind network;
}

abstract interface class DeviceStatusRepository {
  Stream<DeviceStatus> statusChanges();
}

class ChannelDeviceStatusRepository implements DeviceStatusRepository {
  static const _events = EventChannel('swiftdrive/status/events');

  @override
  Stream<DeviceStatus> statusChanges() => _events
      .receiveBroadcastStream()
      .where((e) => e != null)
      .map((e) => DeviceStatus.fromMap(e as Map<Object?, Object?>));
}
