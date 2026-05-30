/// A single point on a route. Elevation is null when the source had no 3rd ordinate.
class RoutePoint {
  final double lat;
  final double lng;
  final double? elevation;

  const RoutePoint({required this.lat, required this.lng, this.elevation});

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, if (elevation != null) 'ele': elevation};
  factory RoutePoint.fromJson(Map<String, dynamic> j) => RoutePoint(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        elevation: j['ele'] == null ? null : (j['ele'] as num).toDouble(),
      );
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

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => p.toJson()).toList(),
        'distanceM': distanceM,
        'ascentM': ascentM,
      };
  factory RouteGeometry.fromJson(Map<String, dynamic> j) => RouteGeometry(
        points: (j['points'] as List).map((e) => RoutePoint.fromJson(e as Map<String, dynamic>)).toList(),
        distanceM: (j['distanceM'] as num).toDouble(),
        ascentM: (j['ascentM'] as num).toDouble(),
      );
}
