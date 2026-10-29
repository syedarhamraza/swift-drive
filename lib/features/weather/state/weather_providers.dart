import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_state.dart';
import '../../../core/logging/app_log.dart';
import '../../../core/storage/settings_providers.dart';
import '../../diagnostics/state/diagnostics_providers.dart';
import '../../location/state/location_providers.dart';
import '../data/weather_repository.dart';

final weatherRepositoryProvider = Provider<WeatherRepository>(
  (ref) => OpenMeteoWeatherRepository(),
);

class WeatherState {
  const WeatherState({this.data, this.failed = false, this.loading = false});

  /// Latest successful result, possibly loaded from cache. Always shown with its timestamp.
  final WeatherData? data;

  /// The last refresh attempt failed (offline, timeout, HTTP error).
  final bool failed;
  final bool loading;
}

const _cacheKey = 'weather_cache_v1';

final weatherProvider = NotifierProvider<WeatherController, WeatherState>(
  WeatherController.new,
);

class WeatherController extends Notifier<WeatherState> {
  (double, double)? _lastCoarse;

  @override
  WeatherState build() {
    final initial = stateOrNull ?? WeatherState(data: _loadCache());
    if (!ref.watch(foregroundProvider) || !ref.stageReached(5)) return initial;
    final minutes = ref.watch(
      settingsProvider.select(
        (s) => s.performanceMode
            ? s.weatherRefreshMinutes * 2
            : s.weatherRefreshMinutes,
      ),
    );

    // Weather needs only a coarse position: react when the 0.1° cell changes, not on every fix.
    ref.listen(
      locationProvider.select((s) => _coarse(s.fix?.lat, s.fix?.lon)),
      (_, cell) {
        if (cell != null && cell != _lastCoarse) refresh();
      },
    );
    final timer = Timer.periodic(Duration(minutes: minutes), (_) => refresh());
    ref.onDispose(timer.cancel);

    final age = initial.data == null
        ? null
        : DateTime.now().difference(initial.data!.fetchedAt);
    if (age == null || age > Duration(minutes: minutes)) {
      Future.microtask(refresh);
    }
    return initial;
  }

  static (double, double)? _coarse(double? lat, double? lon) =>
      lat == null || lon == null
      ? null
      : ((lat * 10).round() / 10, (lon * 10).round() / 10);

  WeatherData? _loadCache() {
    final raw = ref.read(sharedPreferencesProvider).getString(_cacheKey);
    if (raw == null) return null;
    try {
      return WeatherData.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } catch (_) {
      AppLog.w('weather', 'discarding corrupt weather cache');
      return null;
    }
  }

  Future<void> refresh() async {
    final fix = ref.read(locationProvider).fix;
    if (fix == null || state.loading) {
      return; // No position yet: keep the cached result.
    }
    final cell = _coarse(fix.lat, fix.lon)!;
    state = WeatherState(data: state.data, loading: true);
    try {
      var data = await ref
          .read(weatherRepositoryProvider)
          .fetch(
            baseUrl: ref.read(settingsProvider).weatherUrl,
            lat: fix.lat,
            lon: fix.lon,
          );
      String? place = cell == _lastCoarse ? state.data?.locationName : null;
      try {
        place ??= await ref
            .read(deviceRepositoryProvider)
            .reverseGeocode(cell.$1, cell.$2);
      } catch (_) {
        // Place name is optional (Geocoder is often missing without Play Services).
      }
      data = WeatherData.fromJson({...data.toJson(), 'loc': place});
      _lastCoarse = cell;
      if (!ref.mounted) return;
      state = WeatherState(data: data);
      unawaited(
        ref
            .read(sharedPreferencesProvider)
            .setString(_cacheKey, jsonEncode(data.toJson())),
      );
      AppLog.i('weather', 'weather refreshed');
    } catch (e) {
      AppLog.w('weather', 'weather refresh failed: ${e.runtimeType}');
      if (ref.mounted) state = WeatherState(data: state.data, failed: true);
    }
  }
}
