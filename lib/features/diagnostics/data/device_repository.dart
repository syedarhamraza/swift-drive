import 'package:flutter/services.dart';

import '../../../core/platform/platform_failure.dart';

enum CapabilityStatus {
  available,
  unavailable,
  permissionRequired,
  unknown,
  unsupported,
  error,
}

/// Maps the Kotlin enum names (e.g. PERMISSION_REQUIRED). Unrecognised values become [CapabilityStatus.unknown].
CapabilityStatus parseCapabilityStatus(String? raw) => switch (raw) {
  'AVAILABLE' => CapabilityStatus.available,
  'UNAVAILABLE' => CapabilityStatus.unavailable,
  'PERMISSION_REQUIRED' => CapabilityStatus.permissionRequired,
  'UNSUPPORTED' => CapabilityStatus.unsupported,
  'ERROR' => CapabilityStatus.error,
  _ => CapabilityStatus.unknown,
};

class Capability {
  const Capability(this.id, this.label, this.status, this.detail);

  final String id;
  final String label;
  final CapabilityStatus status;
  final String detail;

  Map<String, String> toJson() => {
    'id': id,
    'label': label,
    'status': status.name,
    'detail': detail,
  };
}

class DeviceReport {
  const DeviceReport({
    required this.adapterName,
    required this.device,
    required this.capabilities,
    this.extra,
  });

  factory DeviceReport.fromMap(Map<Object?, Object?> m) => DeviceReport(
    adapterName: (m['adapter'] as Map?)?['name'] as String? ?? 'Unknown',
    device: (m['device'] as Map? ?? const {}).cast<String, Object?>(),
    capabilities: [
      for (final c
          in (m['capabilities'] as List? ?? const [])
              .cast<Map<Object?, Object?>>())
        Capability(
          c['id']! as String,
          c['label']! as String,
          parseCapabilityStatus(c['status'] as String?),
          c['detail'] as String? ?? '',
        ),
    ],
    extra: (m['extra'] as Map?)?.cast<String, Object?>(),
  );

  final String adapterName;
  final Map<String, Object?> device;
  final List<Capability> capabilities;
  final Map<String, Object?>? extra;

  CapabilityStatus statusOf(String id) =>
      capabilities.where((c) => c.id == id).firstOrNull?.status ??
      CapabilityStatus.unknown;
}

abstract interface class DeviceRepository {
  Future<DeviceReport> getReport({bool extra = false});
  Future<String?> reverseGeocode(double lat, double lon);
}

class ChannelDeviceRepository implements DeviceRepository {
  static const _channel = MethodChannel('swiftdrive/device');

  @override
  Future<DeviceReport> getReport({bool extra = false}) => guardPlatform(
    'device',
    () async => DeviceReport.fromMap(
      (await _channel.invokeMapMethod<Object?, Object?>('getReport', {
        'extra': extra,
      }))!,
    ),
  );

  @override
  Future<String?> reverseGeocode(double lat, double lon) => guardPlatform(
    'device',
    () => _channel.invokeMethod<String>('reverseGeocode', {
      'lat': lat,
      'lon': lon,
    }),
  );
}
