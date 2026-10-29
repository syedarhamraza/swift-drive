import 'package:flutter/services.dart';

import '../../../core/platform/platform_failure.dart';

class AppInfo {
  const AppInfo({
    required this.packageName,
    required this.activityName,
    required this.label,
    this.icon,
    this.system = false,
  });

  factory AppInfo.fromMap(Map<Object?, Object?> m) => AppInfo(
    packageName: m['packageName']! as String,
    activityName: m['activityName']! as String,
    label: m['label'] as String? ?? m['packageName']! as String,
    icon: m['icon'] as Uint8List?,
    system: m['system'] as bool? ?? false,
  );

  final String packageName;
  final String activityName;
  final String label;
  final Uint8List? icon;
  final bool system;

  /// Stable identifier used for pins, favourites and factory shortcuts.
  String get id => '$packageName/$activityName';
}

/// Splits an [AppInfo.id] back into package and activity.
(String, String?) parseAppId(String id) {
  final slash = id.indexOf('/');
  return slash < 0
      ? (id, null)
      : (id.substring(0, slash), id.substring(slash + 1));
}

abstract interface class AppsRepository {
  Future<List<AppInfo>> getInstalledApps();
  Stream<String> packageChanges();
  Future<void> launch(String appId);
  Future<void> openGeo(String uri, {String? packageName});
  Future<void> dial();
}

class ChannelAppsRepository implements AppsRepository {
  static const _channel = MethodChannel('swiftdrive/apps');
  static const _events = EventChannel('swiftdrive/apps/events');

  @override
  Future<List<AppInfo>> getInstalledApps() => guardPlatform('apps', () async {
    final list =
        await _channel.invokeListMethod<Map<Object?, Object?>>(
          'getInstalledApps',
        ) ??
        const [];
    return list.map(AppInfo.fromMap).toList();
  }, timeout: const Duration(seconds: 30));

  @override
  Stream<String> packageChanges() =>
      _events.receiveBroadcastStream().map((e) => e as String);

  @override
  Future<void> launch(String appId) {
    final (pkg, activity) = parseAppId(appId);
    return guardPlatform(
      'apps',
      () => _channel.invokeMethod('launchApp', {
        'packageName': pkg,
        'activityName': activity,
      }),
    );
  }

  @override
  Future<void> openGeo(String uri, {String? packageName}) => guardPlatform(
    'apps',
    () => _channel.invokeMethod('openGeo', {
      'uri': uri,
      'packageName': packageName,
    }),
  );

  @override
  Future<void> dial() =>
      guardPlatform('apps', () => _channel.invokeMethod('dial'));
}
