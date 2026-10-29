import 'package:flutter/services.dart';

import '../../../core/platform/platform_failure.dart';

class BluetoothStatus {
  const BluetoothStatus({
    required this.supported,
    required this.enabled,
    required this.permission,
    required this.connectedDevices,
  });

  factory BluetoothStatus.fromMap(Map<Object?, Object?> m) => BluetoothStatus(
    supported: m['supported'] as bool? ?? false,
    enabled: m['enabled'] as bool? ?? false,
    permission: m['permission'] as bool? ?? false,
    connectedDevices: (m['connectedDevices'] as List? ?? const [])
        .cast<String>(),
  );

  final bool supported;
  final bool enabled;
  final bool permission;
  final List<String> connectedDevices;
}

abstract interface class BluetoothRepository {
  Future<BluetoothStatus> getStatus();
  Stream<BluetoothStatus> statusChanges();
}

class ChannelBluetoothRepository implements BluetoothRepository {
  static const _channel = MethodChannel('swiftdrive/bluetooth');
  static const _events = EventChannel('swiftdrive/bluetooth/events');

  @override
  Future<BluetoothStatus> getStatus() => guardPlatform(
    'bluetooth',
    () async => BluetoothStatus.fromMap(
      (await _channel.invokeMapMethod<Object?, Object?>('getStatus'))!,
    ),
  );

  @override
  Stream<BluetoothStatus> statusChanges() => _events
      .receiveBroadcastStream()
      .where((e) => e != null)
      .map((e) => BluetoothStatus.fromMap(e as Map<Object?, Object?>));
}
