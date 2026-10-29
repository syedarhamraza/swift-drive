import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swiftdrive/app.dart';
import 'package:swiftdrive/core/app_state.dart';
import 'package:swiftdrive/core/storage/settings.dart';
import 'package:swiftdrive/core/storage/settings_providers.dart';
import 'package:swiftdrive/core/theme/app_theme.dart';
import 'package:swiftdrive/core/theme/tokens.dart';
import 'package:swiftdrive/features/apps/data/apps_repository.dart';
import 'package:swiftdrive/features/apps/state/apps_providers.dart';
import 'package:swiftdrive/features/bluetooth/data/bluetooth_repository.dart';
import 'package:swiftdrive/features/bluetooth/state/bluetooth_providers.dart';
import 'package:swiftdrive/features/diagnostics/data/device_repository.dart';
import 'package:swiftdrive/features/diagnostics/state/diagnostics_providers.dart';
import 'package:swiftdrive/features/launcher/data/launcher_repository.dart';
import 'package:swiftdrive/features/launcher/state/launcher_providers.dart';
import 'package:swiftdrive/features/location/data/location_repository.dart';
import 'package:swiftdrive/features/location/state/location_providers.dart';
import 'package:swiftdrive/features/media/data/media_repository.dart';
import 'package:swiftdrive/features/media/state/media_providers.dart';
import 'package:swiftdrive/features/navigation/data/navigation_models.dart';
import 'package:swiftdrive/features/navigation/state/navigation_providers.dart';
import 'package:swiftdrive/features/navigation/state/voice_guidance.dart';
import 'package:swiftdrive/features/notifications/data/notifications_repository.dart';
import 'package:swiftdrive/features/notifications/state/notifications_providers.dart';
import 'package:swiftdrive/features/weather/data/weather_repository.dart';
import 'package:swiftdrive/features/weather/state/weather_providers.dart';

// Test-only fakes. Never imported by lib/, so no fake data can reach a production build.

class FakeApps implements AppsRepository {
  FakeApps([this.apps = const []]);

  List<AppInfo> apps;
  final launched = <String>[];
  final changes = StreamController<String>.broadcast();

  @override
  Future<List<AppInfo>> getInstalledApps() async => apps;
  @override
  Stream<String> packageChanges() => changes.stream;
  @override
  Future<void> launch(String appId) async => launched.add(appId);
  @override
  Future<void> openGeo(String uri, {String? packageName}) async =>
      launched.add(uri);
  @override
  Future<void> dial() async => launched.add('dial');
}

class FakeLauncher implements LauncherRepository {
  HomeStatus status = const HomeStatus(
    isDefault: false,
    roleAvailable: true,
    otherHomes: [
      HomeApp('com.example.home', 'com.example.home.Main', 'Stock Home'),
    ],
  );
  PermissionsState permissions = const PermissionsState(
    location: true,
    bluetooth: true,
  );
  final opened = <SettingsPage>[];
  final exported = <String>[];

  @override
  Stream<void> get homePressed => const Stream.empty();
  @override
  Future<HomeStatus> getHomeStatus() async => status;
  @override
  Future<bool?> requestHomeRole() async => true;
  @override
  Future<void> openHomeSettings() async {}
  @override
  Future<void> launchHome(HomeApp app) async {}
  @override
  Future<void> openSettings(SettingsPage page) async => opened.add(page);
  @override
  Future<PermissionsState> getPermissions() async => permissions;
  @override
  Future<bool> requestPermission(AppPermission permission) async => true;
  @override
  Future<bool> exportFile(String fileName, String content) async {
    exported.add(fileName);
    return true;
  }
}

const okStatus = LocationStatus(
  permission: true,
  serviceAvailable: true,
  gpsAvailable: true,
  gpsEnabled: true,
  networkAvailable: true,
  networkEnabled: true,
  locationEnabled: true,
);

class FakeLocation implements LocationRepository {
  final events$ = StreamController<Object>.broadcast();

  @override
  Stream<Object> events() => events$.stream;
  @override
  Future<LocationStatus> getStatus() async => okStatus;
  @override
  Future<void> restart() async {}
}

class FakeMedia implements MediaRepository {
  final snapshots$ = StreamController<MediaSnapshot>.broadcast();
  final commands = <MediaAction>[];

  @override
  Stream<MediaSnapshot> snapshots() => snapshots$.stream;
  @override
  Future<bool> hasAccess() async => true;
  @override
  Future<void> refresh() async {}
  @override
  Future<void> command(
    String sessionId,
    MediaAction action, {
    int? positionMs,
  }) async => commands.add(action);
}

class FakeNotifications implements NotificationsRepository {
  FakeNotifications({this.access = true});

  bool access;
  final items$ = StreamController<List<NotificationItem>>.broadcast();

  @override
  Future<bool> hasAccess() async => access;
  @override
  Stream<List<NotificationItem>> notifications() => items$.stream;
  @override
  Future<void> dismiss(String key) async {}
}

class FakeBluetooth implements BluetoothRepository {
  @override
  Future<BluetoothStatus> getStatus() async => const BluetoothStatus(
    supported: false,
    enabled: false,
    permission: true,
    connectedDevices: [],
  );
  @override
  Stream<BluetoothStatus> statusChanges() => const Stream.empty();
}

class FakeDevice implements DeviceRepository {
  @override
  Future<DeviceReport> getReport({bool extra = false}) async =>
      const DeviceReport(
        adapterName: 'Generic Android',
        device: {
          'manufacturer': 'Test',
          'model': 'HU',
          'release': '9',
          'sdkInt': 28,
          'appVersion': '1.0.0',
          'appBuild': 1,
        },
        capabilities: [
          Capability('gps', 'GPS', CapabilityStatus.available, ''),
          Capability(
            'radio',
            'FM radio control',
            CapabilityStatus.unsupported,
            'Use the Radio shortcut',
          ),
          Capability(
            'notifications',
            'Notification access',
            CapabilityStatus.permissionRequired,
            '',
          ),
        ],
      );
  @override
  Future<String?> reverseGeocode(double lat, double lon) async => null;
}

class FakeWeather implements WeatherRepository {
  WeatherData? result;

  @override
  Future<WeatherData> fetch({
    required String baseUrl,
    required double lat,
    required double lon,
  }) async => result ?? (throw Exception('offline'));
}

class FakeRouting implements RoutingProvider {
  RouteResult? result;
  int calls = 0;

  @override
  Future<RouteResult> route(GeoPoint from, GeoPoint to) async {
    calls++;
    return result ?? (throw Exception('offline'));
  }
}

class FakeGeocoding implements GeocodingProvider {
  List<Place> results = const [];

  @override
  Future<List<Place>> search(String query, {GeoPoint? near}) async => results;
}

class FakeVoice extends VoiceGuidance {
  FakeVoice() : super(() => false);

  final spoken = <String>[];

  @override
  Future<void> say(String text) async => spoken.add(text);
}

class Fakes {
  final apps = FakeApps();
  final launcher = FakeLauncher();
  final location = FakeLocation();
  final media = FakeMedia();
  final notifications = FakeNotifications();
  final bluetooth = FakeBluetooth();
  final device = FakeDevice();
  final weather = FakeWeather();
  final routing = FakeRouting();
  final geocoding = FakeGeocoding();
  final voice = FakeVoice();

  List<Override> overrides(SharedPreferences prefs) => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    appsRepositoryProvider.overrideWithValue(apps),
    launcherRepositoryProvider.overrideWithValue(launcher),
    locationRepositoryProvider.overrideWithValue(location),
    mediaRepositoryProvider.overrideWithValue(media),
    notificationsRepositoryProvider.overrideWithValue(notifications),
    bluetoothRepositoryProvider.overrideWithValue(bluetooth),
    deviceRepositoryProvider.overrideWithValue(device),
    weatherRepositoryProvider.overrideWithValue(weather),
    routingProviderProvider.overrideWithValue(routing),
    geocodingProviderProvider.overrideWithValue(geocoding),
    voiceGuidanceProvider.overrideWithValue(voice),
  ];
}

/// A container with fakes, past every startup stage. The embedded map is off in widget tests because
/// MapLibre is a native platform view.
Future<ProviderContainer> makeContainer(
  Fakes fakes, {
  LauncherSettings settings = const LauncherSettings(
    onboardingDone: true,
    mapEnabled: false,
  ),
}) async {
  SharedPreferences.setMockInitialValues({
    'launcher_settings_v1': jsonEncode(settings.toJson()),
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: fakes.overrides(prefs));
  container.read(startupStageProvider.notifier).completeAll();
  return container;
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The real app shell (theme, routes, lifecycle) on top of fakes.
Future<void> pumpApp(
  WidgetTester tester,
  ProviderContainer container, {
  Size size = const Size(1280, 720),
}) async {
  _setSize(tester, size);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const SwiftDriveApp(),
    ),
  );
  await tester.pump();
}

/// A single widget in a themed scaffold.
Future<void> pumpScreen(
  WidgetTester tester,
  ProviderContainer container,
  Widget screen, {
  Size size = const Size(1280, 720),
}) async {
  _setSize(tester, size);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildTheme(
          Brightness.dark,
          SdColors.accents.first,
          reduceMotion: true,
        ),
        home: Scaffold(body: screen),
      ),
    ),
  );
  await tester.pump();
}

const noMedia = MediaSnapshot(
  access: true,
  sessions: [],
  nativeNow: 0,
  art: {},
);

/// Unmounts the tree and disposes the container so no provider timer outlives the test.
Future<void> tearDownScreen(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(const SizedBox());
  container.dispose();
}
