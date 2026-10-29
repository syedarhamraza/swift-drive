import 'dart:convert';

import '../logging/app_log.dart';

enum AppThemeMode { dark, light, system, auto }

enum DashboardLayout { balanced, mapFocused, mediaFocused, compact }

enum SpeedUnit { kmh, mph }

enum TempUnit { celsius, fahrenheit }

/// Roles a user can map to an installed (often factory) app. No package names are ever assumed.
enum FactoryRole { navigation, music, phone, radio, vehicleSettings }

/// Built-in dock actions. Pinned apps are stored as `app:<package>/<activity>`.
const builtinDockIds = [
  'home',
  'maps',
  'music',
  'phone',
  'radio',
  'apps',
  'settings',
];
const defaultDock = [
  'builtin:home',
  'builtin:maps',
  'builtin:music',
  'builtin:phone',
  'builtin:radio',
  'builtin:apps',
];

const defaultMapStyleLight = 'https://tiles.openfreemap.org/styles/liberty';
const defaultMapStyleDark = 'https://tiles.openfreemap.org/styles/dark';
const defaultRoutingUrl = 'https://routing.openstreetmap.de/routed-car';
const defaultGeocodingUrl = 'https://nominatim.openstreetmap.org';
const defaultWeatherUrl = 'https://api.open-meteo.com/v1/forecast';

/// Immutable launcher settings. Parsing is per-field so one malformed value never discards the rest.
class LauncherSettings {
  const LauncherSettings({
    this.onboardingDone = false,
    this.themeMode = AppThemeMode.dark,
    this.accentIndex = 0,
    this.layout = DashboardLayout.balanced,
    this.use24h = true,
    this.speedUnit = SpeedUnit.kmh,
    this.tempUnit = TempUnit.celsius,
    this.dock = defaultDock,
    this.favorites = const {},
    this.hidden = const {},
    this.shortcuts = const {},
    this.lastMediaPackage,
    this.mapEnabled = true,
    this.mapTextureMode = true,
    this.headingUp = false,
    this.mapStyleLight = defaultMapStyleLight,
    this.mapStyleDark = defaultMapStyleDark,
    this.routingUrl = defaultRoutingUrl,
    this.geocodingUrl = defaultGeocodingUrl,
    this.weatherUrl = defaultWeatherUrl,
    this.voiceMuted = false,
    this.showSpeed = true,
    this.showArtwork = true,
    this.suppressNonEssential = true,
    this.performanceMode = false,
    this.weatherRefreshMinutes = 30,
  });

  final bool onboardingDone;
  final AppThemeMode themeMode;
  final int accentIndex;
  final DashboardLayout layout;
  final bool use24h;
  final SpeedUnit speedUnit;
  final TempUnit tempUnit;
  final List<String> dock;
  final Set<String> favorites;
  final Set<String> hidden;
  final Map<FactoryRole, String> shortcuts;
  final String? lastMediaPackage;
  final bool mapEnabled;
  final bool mapTextureMode;
  final bool headingUp;
  final String mapStyleLight;
  final String mapStyleDark;
  final String routingUrl;
  final String geocodingUrl;
  final String weatherUrl;
  final bool voiceMuted;
  final bool showSpeed;
  final bool showArtwork;
  final bool suppressNonEssential;
  final bool performanceMode;
  final int weatherRefreshMinutes;

  LauncherSettings copyWith({
    bool? onboardingDone,
    AppThemeMode? themeMode,
    int? accentIndex,
    DashboardLayout? layout,
    bool? use24h,
    SpeedUnit? speedUnit,
    TempUnit? tempUnit,
    List<String>? dock,
    Set<String>? favorites,
    Set<String>? hidden,
    Map<FactoryRole, String>? shortcuts,
    String? lastMediaPackage,
    bool? mapEnabled,
    bool? mapTextureMode,
    bool? headingUp,
    String? mapStyleLight,
    String? mapStyleDark,
    String? routingUrl,
    String? geocodingUrl,
    String? weatherUrl,
    bool? voiceMuted,
    bool? showSpeed,
    bool? showArtwork,
    bool? suppressNonEssential,
    bool? performanceMode,
    int? weatherRefreshMinutes,
  }) => LauncherSettings(
    onboardingDone: onboardingDone ?? this.onboardingDone,
    themeMode: themeMode ?? this.themeMode,
    accentIndex: accentIndex ?? this.accentIndex,
    layout: layout ?? this.layout,
    use24h: use24h ?? this.use24h,
    speedUnit: speedUnit ?? this.speedUnit,
    tempUnit: tempUnit ?? this.tempUnit,
    dock: dock ?? this.dock,
    favorites: favorites ?? this.favorites,
    hidden: hidden ?? this.hidden,
    shortcuts: shortcuts ?? this.shortcuts,
    lastMediaPackage: lastMediaPackage ?? this.lastMediaPackage,
    mapEnabled: mapEnabled ?? this.mapEnabled,
    mapTextureMode: mapTextureMode ?? this.mapTextureMode,
    headingUp: headingUp ?? this.headingUp,
    mapStyleLight: mapStyleLight ?? this.mapStyleLight,
    mapStyleDark: mapStyleDark ?? this.mapStyleDark,
    routingUrl: routingUrl ?? this.routingUrl,
    geocodingUrl: geocodingUrl ?? this.geocodingUrl,
    weatherUrl: weatherUrl ?? this.weatherUrl,
    voiceMuted: voiceMuted ?? this.voiceMuted,
    showSpeed: showSpeed ?? this.showSpeed,
    showArtwork: showArtwork ?? this.showArtwork,
    suppressNonEssential: suppressNonEssential ?? this.suppressNonEssential,
    performanceMode: performanceMode ?? this.performanceMode,
    weatherRefreshMinutes: weatherRefreshMinutes ?? this.weatherRefreshMinutes,
  );

  Map<String, Object?> toJson() => {
    'onboardingDone': onboardingDone,
    'themeMode': themeMode.name,
    'accentIndex': accentIndex,
    'layout': layout.name,
    'use24h': use24h,
    'speedUnit': speedUnit.name,
    'tempUnit': tempUnit.name,
    'dock': dock,
    'favorites': favorites.toList(),
    'hidden': hidden.toList(),
    'shortcuts': {for (final e in shortcuts.entries) e.key.name: e.value},
    'lastMediaPackage': lastMediaPackage,
    'mapEnabled': mapEnabled,
    'mapTextureMode': mapTextureMode,
    'headingUp': headingUp,
    'mapStyleLight': mapStyleLight,
    'mapStyleDark': mapStyleDark,
    'routingUrl': routingUrl,
    'geocodingUrl': geocodingUrl,
    'weatherUrl': weatherUrl,
    'voiceMuted': voiceMuted,
    'showSpeed': showSpeed,
    'showArtwork': showArtwork,
    'suppressNonEssential': suppressNonEssential,
    'performanceMode': performanceMode,
    'weatherRefreshMinutes': weatherRefreshMinutes,
  };

  /// Never throws: a missing, corrupt or partially-corrupt blob yields defaults for the bad fields.
  static LauncherSettings fromJsonString(String? raw) {
    if (raw == null) return const LauncherSettings();
    Map<String, Object?> json;
    try {
      json = (jsonDecode(raw) as Map).cast<String, Object?>();
    } catch (e) {
      AppLog.w('settings', 'corrupt settings blob, using defaults');
      return const LauncherSettings();
    }
    const d = LauncherSettings();
    T read<T>(String key, T fallback, T Function(Object? v) parse) {
      if (!json.containsKey(key)) return fallback;
      try {
        return parse(json[key]);
      } catch (_) {
        AppLog.w('settings', 'bad value for $key, using default');
        return fallback;
      }
    }

    E byName<E extends Enum>(List<E> values, Object? v) =>
        values.byName(v! as String);
    List<String> strings(Object? v) =>
        (v! as List).map((e) => e as String).toList();
    String url(Object? v) {
      final s = v! as String;
      final uri = Uri.parse(s);
      if (uri.scheme != 'https' && uri.scheme != 'http') {
        throw const FormatException('not a url');
      }
      return s;
    }

    return LauncherSettings(
      onboardingDone: read(
        'onboardingDone',
        d.onboardingDone,
        (v) => v! as bool,
      ),
      themeMode: read(
        'themeMode',
        d.themeMode,
        (v) => byName(AppThemeMode.values, v),
      ),
      accentIndex: read(
        'accentIndex',
        d.accentIndex,
        (v) => (v! as int).clamp(0, 4),
      ),
      layout: read(
        'layout',
        d.layout,
        (v) => byName(DashboardLayout.values, v),
      ),
      use24h: read('use24h', d.use24h, (v) => v! as bool),
      speedUnit: read(
        'speedUnit',
        d.speedUnit,
        (v) => byName(SpeedUnit.values, v),
      ),
      tempUnit: read('tempUnit', d.tempUnit, (v) => byName(TempUnit.values, v)),
      dock: read('dock', d.dock, strings),
      favorites: read('favorites', d.favorites, (v) => strings(v).toSet()),
      hidden: read('hidden', d.hidden, (v) => strings(v).toSet()),
      shortcuts: read('shortcuts', d.shortcuts, (v) {
        final out = <FactoryRole, String>{};
        for (final e in (v! as Map).entries) {
          final role = FactoryRole.values.asNameMap()[e.key];
          if (role != null && e.value is String) out[role] = e.value as String;
        }
        return out;
      }),
      lastMediaPackage: read('lastMediaPackage', null, (v) => v as String?),
      mapEnabled: read('mapEnabled', d.mapEnabled, (v) => v! as bool),
      mapTextureMode: read(
        'mapTextureMode',
        d.mapTextureMode,
        (v) => v! as bool,
      ),
      headingUp: read('headingUp', d.headingUp, (v) => v! as bool),
      mapStyleLight: read('mapStyleLight', d.mapStyleLight, url),
      mapStyleDark: read('mapStyleDark', d.mapStyleDark, url),
      routingUrl: read('routingUrl', d.routingUrl, url),
      geocodingUrl: read('geocodingUrl', d.geocodingUrl, url),
      weatherUrl: read('weatherUrl', d.weatherUrl, url),
      voiceMuted: read('voiceMuted', d.voiceMuted, (v) => v! as bool),
      showSpeed: read('showSpeed', d.showSpeed, (v) => v! as bool),
      showArtwork: read('showArtwork', d.showArtwork, (v) => v! as bool),
      suppressNonEssential: read(
        'suppressNonEssential',
        d.suppressNonEssential,
        (v) => v! as bool,
      ),
      performanceMode: read(
        'performanceMode',
        d.performanceMode,
        (v) => v! as bool,
      ),
      weatherRefreshMinutes: read(
        'weatherRefreshMinutes',
        d.weatherRefreshMinutes,
        (v) => (v! as int).clamp(15, 180),
      ),
    );
  }
}
