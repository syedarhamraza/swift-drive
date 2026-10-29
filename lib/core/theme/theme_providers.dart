import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/weather/state/weather_providers.dart';
import '../storage/settings.dart';
import '../storage/settings_providers.dart';

/// Day/night from today's sunrise and sunset. Returns whether it is day and when that next changes.
/// After sunset the next change is approximated as tomorrow's sunrise (same clock time).
(bool, DateTime) sunPhase(DateTime now, DateTime sunrise, DateTime sunset) {
  final rise = DateTime(
    now.year,
    now.month,
    now.day,
    sunrise.hour,
    sunrise.minute,
  );
  final set = DateTime(
    now.year,
    now.month,
    now.day,
    sunset.hour,
    sunset.minute,
  );
  if (now.isBefore(rise)) return (false, rise);
  if (now.isBefore(set)) return (true, set);
  return (false, rise.add(const Duration(days: 1)));
}

/// null when there is no usable sun data (then auto mode follows the system).
final autoIsDayProvider = NotifierProvider<AutoDayController, bool?>(
  AutoDayController.new,
);

class AutoDayController extends Notifier<bool?> {
  @override
  bool? build() {
    final data = ref.watch(weatherProvider.select((w) => w.data));
    final rise = data?.sunrise;
    final set = data?.sunset;
    // Sun times drift a few minutes a day; data older than a week is not trusted.
    if (rise == null ||
        set == null ||
        DateTime.now().difference(data!.fetchedAt).inDays > 7) {
      return null;
    }
    final (isDay, next) = sunPhase(DateTime.now(), rise, set);
    final timer = Timer(
      next.difference(DateTime.now()) + const Duration(seconds: 5),
      ref.invalidateSelf,
    );
    ref.onDispose(timer.cancel);
    return isDay;
  }
}

final themeModeProvider = Provider<ThemeMode>((ref) {
  final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
  return switch (mode) {
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.auto => switch (ref.watch(autoIsDayProvider)) {
      true => ThemeMode.light,
      false => ThemeMode.dark,
      null => ThemeMode.system,
    },
  };
});

/// Future hook for a verified headlight-state signal. No adapter provides it today.
abstract interface class HeadlightAdapter {
  Stream<bool>? get headlightsOn;
}
