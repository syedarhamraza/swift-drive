import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// One hourly or daily forecast entry. Daily entries carry the day's high in [tempC] and low in [minC].
class ForecastPoint {
  const ForecastPoint({
    required this.time,
    required this.code,
    required this.tempC,
    this.minC,
    this.isDay = true,
  });

  factory ForecastPoint.fromJson(Map<String, Object?> j) => ForecastPoint(
    time: DateTime.fromMillisecondsSinceEpoch(j['t']! as int),
    code: j['c']! as int,
    tempC: (j['v']! as num).toDouble(),
    minC: (j['lo'] as num?)?.toDouble(),
    isDay: j['d'] as bool? ?? true,
  );

  final DateTime time;
  final int code;
  final double tempC;
  final double? minC;
  final bool isDay;

  Map<String, Object?> toJson() => {
    't': time.millisecondsSinceEpoch,
    'c': code,
    'v': tempC,
    'lo': minC,
    'd': isDay,
  };
}

class WeatherData {
  const WeatherData({
    required this.temperatureC,
    required this.code,
    required this.isDay,
    required this.fetchedAt,
    this.sunrise,
    this.sunset,
    this.locationName,
    this.feelsLikeC,
    this.hourly = const [],
    this.daily = const [],
  });

  /// Parses an Open-Meteo `/v1/forecast` response requested with `timezone=auto` and `timeformat=unixtime`.
  factory WeatherData.fromOpenMeteo(
    Map<String, Object?> json,
    DateTime fetchedAt, {
    String? locationName,
  }) {
    final current = (json['current']! as Map).cast<String, Object?>();
    final daily = (json['daily'] as Map?)?.cast<String, Object?>();
    DateTime? firstTime(String key) {
      final list = daily?[key] as List?;
      final v = list == null || list.isEmpty ? null : list.first as num?;
      return v == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(v.toInt() * 1000);
    }

    // Forecast arrays are optional: entries with a missing value are skipped rather than failing the fetch.
    List<Object?> list(Map<String, Object?>? m, String key) =>
        (m?[key] as List?) ?? const [];
    final hourlyJson = (json['hourly'] as Map?)?.cast<String, Object?>();
    final hTime = list(hourlyJson, 'time');
    final hTemp = list(hourlyJson, 'temperature_2m');
    final hCode = list(hourlyJson, 'weather_code');
    final hDay = list(hourlyJson, 'is_day');
    final dTime = list(daily, 'time');
    final dMax = list(daily, 'temperature_2m_max');
    final dMin = list(daily, 'temperature_2m_min');
    final dCode = list(daily, 'weather_code');
    DateTime at(Object? unix) =>
        DateTime.fromMillisecondsSinceEpoch((unix! as num).toInt() * 1000);

    return WeatherData(
      temperatureC: (current['temperature_2m']! as num).toDouble(),
      code: (current['weather_code']! as num).toInt(),
      isDay: (current['is_day'] as num? ?? 1) == 1,
      sunrise: firstTime('sunrise'),
      sunset: firstTime('sunset'),
      fetchedAt: fetchedAt,
      locationName: locationName,
      feelsLikeC: (current['apparent_temperature'] as num?)?.toDouble(),
      hourly: [
        for (var i = 0; i < hTime.length; i++)
          if (i < hTemp.length &&
              i < hCode.length &&
              hTemp[i] != null &&
              hCode[i] != null)
            ForecastPoint(
              time: at(hTime[i]),
              code: (hCode[i]! as num).toInt(),
              tempC: (hTemp[i]! as num).toDouble(),
              isDay: i >= hDay.length || hDay[i] != 0,
            ),
      ],
      daily: [
        for (var i = 0; i < dTime.length; i++)
          if (i < dMax.length &&
              i < dCode.length &&
              dMax[i] != null &&
              dCode[i] != null)
            ForecastPoint(
              time: at(dTime[i]),
              code: (dCode[i]! as num).toInt(),
              tempC: (dMax[i]! as num).toDouble(),
              minC: i < dMin.length ? (dMin[i] as num?)?.toDouble() : null,
            ),
      ],
    );
  }

  /// Hourly entries from the current hour on.
  List<ForecastPoint> hourlyFrom(DateTime now) => hourly
      .where((p) => !p.time.isBefore(now.subtract(const Duration(hours: 1))))
      .toList();

  factory WeatherData.fromJson(Map<String, Object?> j) => WeatherData(
    temperatureC: (j['t']! as num).toDouble(),
    code: j['code']! as int,
    isDay: j['isDay']! as bool,
    fetchedAt: DateTime.parse(j['fetchedAt']! as String),
    sunrise: j['sunrise'] == null
        ? null
        : DateTime.parse(j['sunrise']! as String),
    sunset: j['sunset'] == null ? null : DateTime.parse(j['sunset']! as String),
    locationName: j['loc'] as String?,
    // Caches written before forecasts existed have none of these keys.
    feelsLikeC: (j['feels'] as num?)?.toDouble(),
    hourly: [
      for (final p in (j['hourly'] as List?) ?? const [])
        ForecastPoint.fromJson((p as Map).cast<String, Object?>()),
    ],
    daily: [
      for (final p in (j['daily'] as List?) ?? const [])
        ForecastPoint.fromJson((p as Map).cast<String, Object?>()),
    ],
  );

  final double temperatureC;
  final int code;
  final bool isDay;
  final DateTime fetchedAt;
  final DateTime? sunrise;
  final DateTime? sunset;
  final String? locationName;
  final double? feelsLikeC;
  final List<ForecastPoint> hourly;

  /// Today first, then the following days.
  final List<ForecastPoint> daily;

  Map<String, Object?> toJson() => {
    't': temperatureC,
    'code': code,
    'isDay': isDay,
    'fetchedAt': fetchedAt.toIso8601String(),
    'sunrise': sunrise?.toIso8601String(),
    'sunset': sunset?.toIso8601String(),
    'loc': locationName,
    'feels': feelsLikeC,
    'hourly': [for (final p in hourly) p.toJson()],
    'daily': [for (final p in daily) p.toJson()],
  };
}

/// WMO weather interpretation codes (as used by Open-Meteo) → label and icon.
(String, IconData) describeWeatherCode(int code, {required bool isDay}) =>
    switch (code) {
      0 => (
        'Clear',
        isDay ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
      ),
      1 || 2 => (
        'Partly cloudy',
        isDay ? Icons.wb_cloudy_outlined : Icons.nights_stay_outlined,
      ),
      3 => ('Overcast', Icons.cloud_outlined),
      45 || 48 => ('Fog', Icons.foggy),
      51 || 53 || 55 || 56 || 57 => ('Drizzle', Icons.grain),
      61 ||
      63 ||
      65 ||
      66 ||
      67 ||
      80 ||
      81 ||
      82 => ('Rain', Icons.water_drop_outlined),
      71 || 73 || 75 || 77 || 85 || 86 => ('Snow', Icons.ac_unit),
      95 || 96 || 99 => ('Thunderstorm', Icons.thunderstorm_outlined),
      _ => ('Unknown', Icons.help_outline),
    };

abstract interface class WeatherRepository {
  Future<WeatherData> fetch({
    required String baseUrl,
    required double lat,
    required double lon,
  });
}

/// Open-Meteo (free, keyless, non-commercial use; data CC BY 4.0). No API key is involved.
class OpenMeteoWeatherRepository implements WeatherRepository {
  OpenMeteoWeatherRepository([http.Client? client])
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<WeatherData> fetch({
    required String baseUrl,
    required double lat,
    required double lon,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      queryParameters: {
        // ~1 km precision is plenty for weather and avoids sending an exact position.
        'latitude': lat.toStringAsFixed(2),
        'longitude': lon.toStringAsFixed(2),
        // One request covers the card, the forecast and the sunrise/sunset theme.
        'current': 'temperature_2m,weather_code,is_day,apparent_temperature',
        'hourly': 'temperature_2m,weather_code,is_day',
        'forecast_hours': '6',
        'daily':
            'sunrise,sunset,temperature_2m_max,temperature_2m_min,weather_code',
        'forecast_days': '4',
        'timezone': 'auto',
        'timeformat': 'unixtime',
      },
    );
    final res = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw http.ClientException('weather HTTP ${res.statusCode}', uri);
    }
    return WeatherData.fromOpenMeteo(
      (jsonDecode(res.body) as Map).cast<String, Object?>(),
      DateTime.now(),
    );
  }
}
