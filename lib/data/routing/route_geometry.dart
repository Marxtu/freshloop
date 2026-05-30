/// A single point on a route. Elevation is null when the source had no 3rd ordinate.
class RoutePoint {
  final double lat;
  final double lng;
  final double? elevation;

  const RoutePoint({required this.lat, required this.lng, this.elevation});
}

/// A route's geometry plus the summary metrics needed for scoring.
class RouteGeometry {
  final List<RoutePoint> points;
  final double distanceM;
  final double ascentM;

  const RouteGeometry({
    required this.points,
    required this.distanceM,
    required this.ascentM,
  });

  /// Parses an OpenRouteService GeoJSON directions response. Coordinates are
  /// `[lng, lat, elevation?]`. Throws [FormatException] if no feature is present.
  factory RouteGeometry.fromOrsGeoJson(Map<String, dynamic> json) {
    final features = (json['features'] as List?) ?? const [];
    if (features.isEmpty) {
      throw const FormatException('ORS response has no features');
    }
    final feature = features.first as Map<String, dynamic>;
    final coords = (feature['geometry'] as Map<String, dynamic>)['coordinates'] as List;
    final props = feature['properties'] as Map<String, dynamic>;
    final summary = (props['summary'] as Map<String, dynamic>?) ?? const {};

    final points = coords.map((c) {
      final list = c as List;
      return RoutePoint(
        lng: (list[0] as num).toDouble(),
        lat: (list[1] as num).toDouble(),
        elevation: list.length > 2 ? (list[2] as num).toDouble() : null,
      );
    }).toList();

    return RouteGeometry(
      points: points,
      distanceM: ((summary['distance'] as num?) ?? 0).toDouble(),
      ascentM: ((props['ascent'] as num?) ?? 0).toDouble(),
    );
  }
}
