import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:swiftdrive/core/storage/settings.dart';

void main() {
  test('missing blob gives defaults', () {
    final s = LauncherSettings.fromJsonString(null);
    expect(s.onboardingDone, isFalse);
    expect(s.dock, defaultDock);
  });

  test('unparseable blob gives defaults instead of crashing', () {
    expect(
      LauncherSettings.fromJsonString('{not json').themeMode,
      const LauncherSettings().themeMode,
    );
    expect(LauncherSettings.fromJsonString('[1,2]').onboardingDone, isFalse);
  });

  test('round trip keeps every field', () {
    const s = LauncherSettings(
      onboardingDone: true,
      themeMode: AppThemeMode.light,
      layout: DashboardLayout.mapFocused,
      speedUnit: SpeedUnit.mph,
      favorites: {'a/b'},
      hidden: {'c/d'},
      shortcuts: {FactoryRole.radio: 'r/x'},
      lastMediaPackage: 'com.music',
      weatherRefreshMinutes: 45,
    );
    final back = LauncherSettings.fromJsonString(jsonEncode(s.toJson()));
    expect(jsonEncode(back.toJson()), jsonEncode(s.toJson()));
  });

  test('one bad field falls back alone; others survive', () {
    final raw = jsonEncode({
      ...const LauncherSettings(onboardingDone: true).toJson(),
      'themeMode': 'purple',
      'routingUrl': 'javascript:alert(1)',
      'favorites': 42,
    });
    final s = LauncherSettings.fromJsonString(raw);
    expect(s.onboardingDone, isTrue);
    expect(s.themeMode, const LauncherSettings().themeMode);
    expect(s.routingUrl, defaultRoutingUrl);
    expect(s.favorites, isEmpty);
  });
}
