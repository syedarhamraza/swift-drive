import 'dart:async';

import 'package:flutter/services.dart';

import '../../../core/platform/platform_failure.dart';

class HomeApp {
  const HomeApp(this.packageName, this.activityName, this.label);

  final String packageName;
  final String activityName;
  final String label;
}

class HomeStatus {
  const HomeStatus({
    required this.isDefault,
    required this.roleAvailable,
    required this.otherHomes,
  });

  final bool isDefault;
  final bool roleAvailable;
  final List<HomeApp> otherHomes;
}

class PermissionsState {
  const PermissionsState({required this.location, required this.bluetooth});

  final bool location;
  final bool bluetooth;
}

enum AppPermission { location, bluetooth }

enum SettingsPage {
  appDetails,
  location,
  bluetooth,
  notificationAccess,
  home,
  tts,
  system,
}

abstract interface class LauncherRepository {
  Future<HomeStatus> getHomeStatus();

  /// True/false when the system role dialog reported a result; null when only settings were opened.
  Future<bool?> requestHomeRole();
  Future<void> openHomeSettings();
  Future<void> launchHome(HomeApp app);
  Future<void> openSettings(SettingsPage page);
  Future<PermissionsState> getPermissions();
  Future<bool> requestPermission(AppPermission permission);

  /// Saves [content] through the system document picker. Returns false if the user cancelled.
  Future<bool> exportFile(String fileName, String content);

  /// Fires when HOME is pressed while SwiftDrive is already running.
  Stream<void> get homePressed;
}

class ChannelLauncherRepository implements LauncherRepository {
  ChannelLauncherRepository() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'homePressed') _home.add(null);
    });
  }

  static const _channel = MethodChannel('swiftdrive/launcher');
  final _home = StreamController<void>.broadcast();

  @override
  Stream<void> get homePressed => _home.stream;

  @override
  Future<HomeStatus> getHomeStatus() => guardPlatform('launcher', () async {
    final m = (await _channel.invokeMapMethod<String, Object?>(
      'getHomeStatus',
    ))!;
    return HomeStatus(
      isDefault: m['isDefault']! as bool,
      roleAvailable: m['roleAvailable']! as bool,
      otherHomes: [
        for (final h
            in (m['otherHomes']! as List).cast<Map<Object?, Object?>>())
          HomeApp(
            h['packageName']! as String,
            h['activityName']! as String,
            h['label']! as String,
          ),
      ],
    );
  });

  // The role dialog waits for the user, so no timeout applies.
  @override
  Future<bool?> requestHomeRole() => guardPlatform(
    'launcher',
    () => _channel.invokeMethod<bool>('requestHomeRole'),
    timeout: const Duration(days: 1),
  );

  @override
  Future<void> openHomeSettings() => guardPlatform(
    'launcher',
    () => _channel.invokeMethod('openHomeSettings'),
  );

  @override
  Future<void> launchHome(HomeApp app) => guardPlatform(
    'launcher',
    () => _channel.invokeMethod('launchHome', {
      'packageName': app.packageName,
      'activityName': app.activityName,
    }),
  );

  @override
  Future<void> openSettings(SettingsPage page) => guardPlatform(
    'launcher',
    () => _channel.invokeMethod('openSettings', {'page': page.name}),
  );

  @override
  Future<PermissionsState> getPermissions() =>
      guardPlatform('launcher', () async {
        final m = (await _channel.invokeMapMethod<String, bool>(
          'getPermissions',
        ))!;
        return PermissionsState(
          location: m['location'] ?? false,
          bluetooth: m['bluetooth'] ?? false,
        );
      });

  @override
  Future<bool> requestPermission(AppPermission permission) => guardPlatform(
    'launcher',
    () async =>
        await _channel.invokeMethod<bool>('requestPermission', {
          'name': permission.name,
        }) ??
        false,
    timeout: const Duration(days: 1),
  );

  @override
  Future<bool> exportFile(String fileName, String content) => guardPlatform(
    'launcher',
    () async =>
        await _channel.invokeMethod<bool>('exportFile', {
          'fileName': fileName,
          'content': content,
        }) ??
        false,
    timeout: const Duration(days: 1),
  );
}
