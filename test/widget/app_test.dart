import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftdrive/core/app_state.dart';
import 'package:swiftdrive/core/storage/settings.dart';
import 'package:swiftdrive/core/storage/settings_providers.dart';
import 'package:swiftdrive/features/apps/data/apps_repository.dart';
import 'package:swiftdrive/features/apps/ui/app_drawer_screen.dart';
import 'package:swiftdrive/features/dashboard/ui/dashboard_screen.dart';
import 'package:swiftdrive/features/diagnostics/ui/diagnostics_screen.dart';
import 'package:swiftdrive/features/location/data/location_repository.dart';
import 'package:swiftdrive/features/location/state/location_providers.dart';
import 'package:swiftdrive/features/location/ui/speed_card.dart';
import 'package:swiftdrive/features/media/data/media_repository.dart';
import 'package:swiftdrive/features/media/ui/media_card.dart';
import 'package:swiftdrive/features/notifications/data/notifications_repository.dart';
import 'package:swiftdrive/features/notifications/state/notifications_providers.dart';
import 'package:swiftdrive/features/onboarding/ui/onboarding_screen.dart';
import 'package:swiftdrive/features/settings/ui/settings_screen.dart';
import 'package:swiftdrive/features/weather/data/weather_repository.dart';
import 'package:swiftdrive/features/weather/ui/weather_card.dart';

import '../fakes/fakes.dart';

const headUnitSizes = [
  Size(1024, 600),
  Size(1280, 720),
  Size(1280, 800),
  Size(1920, 720),
];

LocationFix fix({double? speed}) => LocationFix(
  provider: 'gps',
  lat: 33.68,
  lon: 73.04,
  fixTime: monotonicNow(),
  accuracy: 5,
  speed: speed,
  speedAccuracy: 0.5,
);

void main() {
  late Fakes fakes;
  late ProviderContainer c;

  setUp(() async {
    fakes = Fakes();
    c = await makeContainer(fakes);
  });

  group('dashboard', () {
    for (final size in headUnitSizes) {
      testWidgets(
        'renders without overflow at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          await pumpApp(tester, c, size: size);
          fakes.media.snapshots$.add(noMedia);
          await tester.pump();

          expect(find.byType(DashboardScreen), findsOneWidget);
          expect(find.text('Nothing playing'), findsOneWidget);
          expect(
            find.text('Settings'),
            findsOneWidget,
            reason: 'Settings stays reachable from the dock',
          );
          // Map disabled in tests → fallback with an external-navigation option.
          expect(tester.takeException(), isNull);
          await tearDownScreen(tester, c);
        },
      );
    }

    testWidgets('portrait phone layout renders without overflow', (
      tester,
    ) async {
      await pumpApp(tester, c, size: const Size(412, 915));
      fakes.media.snapshots$.add(noMedia);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tearDownScreen(tester, c);
    });

    testWidgets('whole dock fits a 1024x600 hdpi head unit (683x400 dp)', (
      tester,
    ) async {
      await pumpApp(tester, c, size: const Size(683, 400));
      for (final label in ['Home', 'Apps', 'Settings']) {
        expect(
          find.byTooltip(label).hitTestable(),
          findsOneWidget,
          reason: label,
        );
      }
      expect(tester.takeException(), isNull);
      await tearDownScreen(tester, c);
    });

    testWidgets('theme follows the setting instantly', (tester) async {
      await pumpApp(tester, c);
      Brightness brightness() =>
          Theme.of(tester.element(find.byType(DashboardScreen))).brightness;
      expect(brightness(), Brightness.dark);
      c
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(themeMode: AppThemeMode.light));
      await tester.pump();
      expect(brightness(), Brightness.light);
      await tearDownScreen(tester, c);
    });

    testWidgets('first launch shows onboarding; Skip lands on the dashboard', (
      tester,
    ) async {
      c = await makeContainer(
        fakes,
        settings: const LauncherSettings(mapEnabled: false),
      );
      await pumpApp(tester, c);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(c.read(settingsProvider).onboardingDone, isTrue);
      await tearDownScreen(tester, c);
    });
  });

  group('media card', () {
    testWidgets('no notification access explains and links to settings', (
      tester,
    ) async {
      await pumpScreen(tester, c, const MediaCard());
      fakes.media.snapshots$.add(
        const MediaSnapshot(access: false, sessions: [], nativeNow: 0, art: {}),
      );
      await tester.pump();
      await tester.tap(find.text('Enable access'));
      expect(fakes.launcher.opened, isNotEmpty);
      await tearDownScreen(tester, c);
    });

    testWidgets('playing session shows metadata and sends commands', (
      tester,
    ) async {
      await pumpScreen(tester, c, const MediaCard());
      fakes.media.snapshots$.add(
        const MediaSnapshot(
          access: true,
          nativeNow: 1000,
          art: {},
          sessions: [
            MediaSession(
              id: 'm',
              packageName: 'com.music',
              appLabel: 'Music',
              state: PlaybackStates.playing,
              position: 0,
              updateTime: 1000,
              speed: 1,
              actions: 0,
              title: 'Track A',
              artist: 'Artist B',
              duration: 200000,
            ),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Track A'), findsOneWidget);
      await tester.tap(find.byTooltip('Pause'));
      await tester.tap(find.byTooltip('Next'));
      expect(fakes.media.commands, [MediaAction.pause, MediaAction.next]);
      await tearDownScreen(tester, c);
    });
  });

  group('speed card', () {
    testWidgets('acquiring, then valid GPS speed in km/h', (tester) async {
      await pumpScreen(tester, c, const SpeedCard());
      expect(find.text('Acquiring GPS…'), findsOneWidget);
      fakes.location.events$
        ..add(okStatus)
        ..add(fix(speed: 10));
      await tester.pump();
      await tester.pump();
      expect(find.text('36'), findsOneWidget);
      expect(find.text('km/h'), findsOneWidget);
      await tearDownScreen(tester, c);
    });

    testWidgets('GPS switched off offers to turn it on', (tester) async {
      await pumpScreen(tester, c, const SpeedCard());
      fakes.location.events$.add(
        const LocationStatus(
          permission: true,
          serviceAvailable: true,
          gpsAvailable: true,
          gpsEnabled: false,
          networkAvailable: true,
          networkEnabled: false,
          locationEnabled: false,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('GPS is off'), findsOneWidget);
      expect(find.text('Turn on'), findsOneWidget);
      await tearDownScreen(tester, c);
    });
  });

  group('weather', () {
    testWidgets('without a location says so instead of inventing weather', (
      tester,
    ) async {
      await pumpScreen(tester, c, const WeatherSummary());
      expect(find.text('Weather needs a location'), findsOneWidget);
      await tearDownScreen(tester, c);
    });

    testWidgets('fetches for the current position', (tester) async {
      fakes.weather.result = WeatherData(
        temperatureC: 29.6,
        code: 0,
        isDay: true,
        fetchedAt: DateTime.now(),
      );
      await pumpScreen(tester, c, const WeatherSummary());
      fakes.location.events$.add(fix());
      await tester.pump();
      await tester.pump();
      expect(find.text('30°C'), findsOneWidget);
      await tearDownScreen(tester, c);
    });

    testWidgets('offline with no cache shows the offline state', (
      tester,
    ) async {
      await pumpScreen(tester, c, const WeatherSummary());
      fakes.location.events$.add(fix());
      await tester.pump();
      await tester.pump();
      expect(find.text('Offline — no cached weather'), findsOneWidget);
      await tearDownScreen(tester, c);
    });
  });

  group('screens', () {
    testWidgets('drawer searches and launches the tapped app', (tester) async {
      fakes.apps.apps = const [
        AppInfo(
          packageName: 'com.music',
          activityName: 'M',
          label: 'Music Player',
        ),
        AppInfo(packageName: 'com.radio', activityName: 'R', label: 'FM Radio'),
      ];
      await pumpApp(tester, c);
      await tester.tap(find.text('Apps'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDrawerScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'radio');
      await tester.pump();
      expect(find.text('Music Player'), findsNothing);
      await tester.tap(find.text('FM Radio'));
      await tester.pump();
      expect(fakes.apps.launched, ['com.radio/R']);
      await tearDownScreen(tester, c);
    });

    testWidgets('settings toggles persist', (tester) async {
      await pumpApp(tester, c, size: const Size(1280, 800));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.tap(find.text('Use 24-hour clock'));
      await tester.pump();
      expect(c.read(settingsProvider).use24h, isFalse);
      expect(
        c.read(sharedPreferencesProvider).getString('launcher_settings_v1'),
        contains('"use24h":false'),
      );
      await tearDownScreen(tester, c);
    });

    testWidgets('diagnostics lists real capability states and exports JSON', (
      tester,
    ) async {
      await pumpApp(tester, c);
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.pushNamed(DiagnosticsScreen.route);
      await tester.pumpAndSettle();
      expect(find.text('FM radio control'), findsOneWidget);
      await tester.tap(find.text('Export report (JSON)'));
      await tester.pump();
      expect(fakes.launcher.exported.single, endsWith('.json'));
      expect(tester.takeException(), isNull);
      await tearDownScreen(tester, c);
    });
  });

  test('native streams stop while the launcher is in the background', () async {
    c.listen(locationProvider, (_, _) {});
    expect(fakes.location.events$.hasListener, isTrue);
    c.read(foregroundProvider.notifier).set(false);
    await pumpEventQueue();
    c.read(locationProvider);
    expect(fakes.location.events$.hasListener, isFalse);
    c.dispose();
  });

  test(
    'notification contents are dropped when the launcher is hidden',
    () async {
      c.listen(notificationsProvider, (_, _) {});
      await pumpEventQueue();
      fakes.notifications.items$.add([
        NotificationItem(
          key: 'k',
          packageName: 'p',
          appLabel: 'P',
          title: 'Hi',
          postTime: DateTime(2026),
          clearable: true,
        ),
      ]);
      await pumpEventQueue();
      expect(c.read(notificationsProvider).items, hasLength(1));
      c.read(foregroundProvider.notifier).set(false);
      final hidden = c.read(notificationsProvider);
      expect(hidden.items, isEmpty);
      expect(hidden.access, isTrue);
      c.dispose();
    },
  );
}
