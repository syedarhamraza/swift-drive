import 'dart:convert';

import 'package:http/http.dart' as http;

import 'navigation_models.dart';

/// Identifies the app to OSM community services, as their usage policies require.
const userAgent =
    'SwiftDrive/1.0 (personal Android car launcher; com.swiftdrive.launcher)';

/// The public OSM services allow at most one request per second per application.
class _RateLimiter {
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> wait() async {
    final next = _last.add(const Duration(seconds: 1));
    final now = DateTime.now();
    if (now.isBefore(next)) await Future<void>.delayed(next.difference(now));
    _last = DateTime.now();
  }
}

class OsrmRoutingProvider implements RoutingProvider {
  OsrmRoutingProvider(this.baseUrl, [http.Client? client])
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  final _limiter = _RateLimiter();

  @override
  Future<RouteResult> route(GeoPoint from, GeoPoint to) async {
    await _limiter.wait();
    final coords = '${from.lon},${from.lat};${to.lon},${to.lat}';
    final uri = Uri.parse('$baseUrl/route/v1/driving/$coords').replace(
      queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'true',
      },
    );
    final res = await _client
        .get(uri, headers: {'User-Agent': userAgent})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw http.ClientException('routing HTTP ${res.statusCode}', uri);
    }
    return parseOsrmRoute(
      (jsonDecode(res.body) as Map).cast<String, Object?>(),
    );
  }
}

RouteResult parseOsrmRoute(Map<String, Object?> json) {
  if (json['code'] != 'Ok') {
    throw FormatException('routing failed: ${json['code']}');
  }
  final route = ((json['routes']! as List).first as Map)
      .cast<String, Object?>();
  final coords = ((route['geometry']! as Map)['coordinates']! as List)
      .cast<List<Object?>>();
  final steps = <RouteStep>[];
  for (final leg
      in (route['legs'] as List? ?? const []).cast<Map<Object?, Object?>>()) {
    for (final s
        in (leg['steps'] as List? ?? const []).cast<Map<Object?, Object?>>()) {
      final m = (s['maneuver']! as Map).cast<String, Object?>();
      final loc = (m['location']! as List).cast<num>();
      final type = m['type']! as String;
      final modifier = m['modifier'] as String?;
      steps.add(
        RouteStep(
          instruction: maneuverText(type, modifier, s['name'] as String?),
          location: GeoPoint(loc[1].toDouble(), loc[0].toDouble()),
          type: type,
          modifier: modifier,
        ),
      );
    }
  }
  return RouteResult(
    geometry: [
      for (final c in coords)
        GeoPoint((c[1]! as num).toDouble(), (c[0]! as num).toDouble()),
    ],
    distanceMeters: (route['distance']! as num).toDouble(),
    durationSeconds: (route['duration']! as num).toDouble(),
    steps: steps,
  );
}

/// Short English instruction built only from the provider's maneuver type, modifier and road name.
String maneuverText(String type, String? modifier, String? road) {
  final onto = (road == null || road.isEmpty) ? '' : ' onto $road';
  final dir = modifier ?? 'straight';
  return switch (type) {
    'depart' => 'Head ${road == null || road.isEmpty ? 'out' : 'along $road'}',
    'arrive' => 'Arrive at destination',
    'roundabout' || 'rotary' => 'Enter the roundabout$onto',
    'merge' => 'Merge$onto',
    'on ramp' => 'Take the ramp$onto',
    'off ramp' => 'Take the exit$onto',
    'fork' => 'Keep $dir at the fork$onto',
    'end of road' => 'At the end of the road, turn $dir$onto',
    'continue' ||
    'new name' => dir == 'straight' ? 'Continue$onto' : 'Continue $dir$onto',
    _ =>
      dir == 'straight'
          ? 'Go straight$onto'
          : (dir == 'uturn' ? 'Make a U-turn$onto' : 'Turn $dir$onto'),
  };
}

class NominatimGeocodingProvider implements GeocodingProvider {
  NominatimGeocodingProvider(this.baseUrl, [http.Client? client])
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  final _limiter = _RateLimiter();
  final _cache = <String, List<Place>>{}; // Nominatim policy: cache results.

  @override
  Future<List<Place>> search(String query, {GeoPoint? near}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final cached = _cache[q.toLowerCase()];
    if (cached != null) return cached;
    await _limiter.wait();
    final params = {'q': q, 'format': 'jsonv2', 'limit': '6'};
    if (near != null) {
      // Bias (not restrict) results to ~100 km around the vehicle.
      params['viewbox'] =
          '${near.lon - 1},${near.lat + 1},${near.lon + 1},${near.lat - 1}';
    }
    final uri = Uri.parse('$baseUrl/search').replace(queryParameters: params);
    final res = await _client
        .get(uri, headers: {'User-Agent': userAgent})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw http.ClientException('geocoding HTTP ${res.statusCode}', uri);
    }
    final results = [
      for (final r
          in (jsonDecode(res.body) as List).cast<Map<Object?, Object?>>())
        Place(
          (r['name'] as String?)?.isNotEmpty == true
              ? r['name']! as String
              : (r['display_name']! as String).split(',').first,
          GeoPoint(
            double.parse(r['lat']! as String),
            double.parse(r['lon']! as String),
          ),
          detail: r['display_name'] as String?,
        ),
    ];
    _cache[q.toLowerCase()] = results;
    return results;
  }
}
