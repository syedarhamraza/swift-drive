class GeoPoint {
  const GeoPoint(this.lat, this.lon);

  final double lat;
  final double lon;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);
}

class Place {
  const Place(this.name, this.point, {this.detail});

  final String name;
  final String? detail;
  final GeoPoint point;
}

class RouteStep {
  const RouteStep({
    required this.instruction,
    required this.location,
    required this.type,
    this.modifier,
  });

  final String instruction;
  final GeoPoint location;
  final String type;
  final String? modifier;
}

class RouteResult {
  const RouteResult({
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
  });

  final List<GeoPoint> geometry;
  final double distanceMeters;
  final double durationSeconds;

  /// Maneuvers exactly as supplied by the provider. Empty when the provider gives none.
  final List<RouteStep> steps;
}

/// Swappable routing backend (OSRM today; Valhalla/GraphHopper could implement this too).
abstract interface class RoutingProvider {
  Future<RouteResult> route(GeoPoint from, GeoPoint to);
}

/// Swappable geocoder. Called only on explicit submit — never as autocomplete.
abstract interface class GeocodingProvider {
  Future<List<Place>> search(String query, {GeoPoint? near});
}
