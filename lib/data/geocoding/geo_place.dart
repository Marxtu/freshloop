/// A geocoded place: coordinates plus a human-readable label.
class GeoPlace {
  final double lat;
  final double lng;
  final String label;

  const GeoPlace({required this.lat, required this.lng, required this.label});

  /// Parses one Nominatim `jsonv2` result. `lat`/`lon` arrive as strings.
  factory GeoPlace.fromNominatimJson(Map<String, dynamic> json) {
    return GeoPlace(
      lat: double.parse(json['lat'] as String),
      lng: double.parse(json['lon'] as String),
      label: (json['display_name'] as String?) ?? '',
    );
  }
}
