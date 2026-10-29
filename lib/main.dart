import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/logging/app_log.dart';
import 'core/perf/perf_metrics.dart';
import 'core/storage/settings_providers.dart';

Future<void> main() async {
  final startup = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();

  // Unexpected errors are logged and never take the launcher down.
  FlutterError.onError = (details) {
    AppLog.e('flutter', details.exceptionAsString());
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.e('uncaught', error.toString());
    return true;
  };

  // Settings are loaded before the first frame (a few ms) so the correct dark theme is used from the
  // start, avoiding a bright flash at night. Everything slower is staged after the first frame.
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  MapLibreMap.useHybridComposition = container
      .read(settingsProvider)
      .mapTextureMode;
  PerfMetrics.install();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: SwiftDriveApp(startupWatch: startup),
    ),
  );
}
