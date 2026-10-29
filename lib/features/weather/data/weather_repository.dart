import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WeatherData {
  const WeatherData({
    required this.temperatureC,
    required this.code,
    required this.isDay,
    required this.fetchedAt,
    this.sunrise,
    this.sunset,
    this.locationName,
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

    return WeatherData(
      temperatureC: (current['temperature_2m']! as num).toDouble(),
      code: (current['weather_code']! as num).toInt(),
      isDay: (current['is_day'] as num? ?? 1) == 1,
      sunrise: firstTime('sunrise'),
      sunset: firstTime('sunset'),
      fetchedAt: fetchedAt,
      locationName: locationName,
    );
  }

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
  );

  final double temperatureC;
  final int code;
  final bool isDay;
  final DateTime fetchedAt;
  final DateTime? sunrise;
  final DateTime? sunset;
  final String? locationName;

  Map<String, Object?> toJson() => {
    't': temperatureC,
    'code': code,
    'isDay': isDay,
    'fetchedAt': fetchedAt.toIso8601String(),
    'sunrise': sunrise?.toIso8601String(),
    'sunset': sunset?.toIso8601String(),
    'loc': locationName,
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
        'current': 'temperature_2m,weather_code,is_day',
        'daily': 'sunrise,sunset',
        'forecast_days': '1',
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
