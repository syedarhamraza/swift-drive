import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_log.dart';
import 'settings.dart';

/// Overridden in main() with the instance loaded before the first frame.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);

const _settingsKey = 'launcher_settings_v1';

final settingsProvider = NotifierProvider<SettingsController, LauncherSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<LauncherSettings> {
  @override
  LauncherSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return LauncherSettings.fromJsonString(prefs.getString(_settingsKey));
  }

  void update(LauncherSettings Function(LauncherSettings s) change) {
    final next = change(state);
    state = next;
    ref
        .read(sharedPreferencesProvider)
        .setString(_settingsKey, jsonEncode(next.toJson()))
        .catchError((Object e) {
          AppLog.e('settings', 'failed to persist settings: $e');
          return false;
        });
  }

  void reset() => update((_) => const LauncherSettings(onboardingDone: true));
}
