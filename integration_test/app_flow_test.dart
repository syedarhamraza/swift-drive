import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swiftdrive/app.dart';
import 'package:swiftdrive/core/platform/platform_failure.dart';
import 'package:swiftdrive/core/storage/settings.dart';
import 'package:swiftdrive/core/storage/settings_providers.dart';
import 'package:swiftdrive/features/apps/state/apps_providers.dart';
import 'package:swiftdrive/features/apps/ui/app_drawer_screen.dart';
import 'package:swiftdrive/features/dashboard/ui/dashboard_screen.dart';
import 'package:swiftdrive/features/diagnostics/ui/diagnostics_screen.dart';
import 'package:swiftdrive/features/onboarding/ui/onboarding_screen.dart';
import 'package:swiftdrive/main.dart' as app;

/// Runs against the real platform channels on a device or emulator; nothing is faked.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The dashboard has live content (map, progress indicators), so it never "settles"; poll instead.
  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    int seconds = 15,
  }) async {
    for (var i = 0; i < seconds * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    throw TestFailure('Timed out waiting for $finder');
  }

  testWidgets(
    'first run → dashboard → drawer → launch error path → diagnostics → theme → restart',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // main() installs the app's error handlers; the test binding needs its own back.
      final testOnError = FlutterError.onError;
      await app.main();
      FlutterError.onError = testOnError;
      await waitFor(tester, find.byType(OnboardingScreen));
      await tester.tap(find.text('Skip'));
      await waitFor(tester, find.byType(DashboardScreen));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SwiftDriveApp)),
      );

      // The drawer lists real launchable apps (SwiftDrive excludes itself). Launching one would send the
      // test to the background, so the native launch path is checked with a missing package instead.
      // Tooltip, not text: on small screens the dock shows icons only.
      await tester.tap(find.byTooltip('Apps'));
      await waitFor(tester, find.byType(AppDrawerScreen));
      await tester.enterText(find.byType(TextField), 'Settings');
      await waitFor(
        tester,
        find.descendant(
          of: find.byType(GridView),
          matching: find.text('Settings'),
        ),
      );
      final failure = await container
          .read(appLauncherProvider)
          .launch('com.example.not.installed/.Main');
      expect(failure?.kind, FailureKind.activityMissing);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await waitFor(tester, find.byType(DashboardScreen));

      // Diagnostics runs the real capability detector.
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed(DiagnosticsScreen.route);
      // The capability list is long on real devices, so the export button may be below the fold.
      await waitFor(tester, find.byType(CapabilityList));
      expect(find.textContaining('Profile: Generic Android'), findsOneWidget);
      expect(find.text('Diagnostics unavailable'), findsNothing);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await waitFor(tester, find.byType(DashboardScreen));

      Brightness brightness() =>
          Theme.of(tester.element(find.byType(DashboardScreen))).brightness;
      expect(brightness(), Brightness.dark);
      container
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(themeMode: AppThemeMode.light));
      await tester.pump(const Duration(milliseconds: 300));
      expect(brightness(), Brightness.light);

      // A cold start reads the same persisted settings: onboarding stays done, theme stays light.
      final reloaded = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      expect(reloaded.read(settingsProvider).onboardingDone, isTrue);
      expect(reloaded.read(settingsProvider).themeMode, AppThemeMode.light);
      reloaded.dispose();

      container
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(themeMode: AppThemeMode.dark));
      await tester.pump(const Duration(milliseconds: 300));
    },
  );
}
