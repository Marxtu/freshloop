import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_exception.dart';
import 'geo_place.dart';

/// Client for the Photon geocoder (Komoot, OSM-based). Unlike Nominatim's
/// `/search`, Photon is built for **type-ahead**: it prefix-matches as the user
/// types (so "Carre" surfaces "Carrefour", not towns literally named "Carre")
/// and biases results toward [lat]/[lng]. Keyless; a descriptive User-Agent is
/// polite. Inject [client] in tests; defaults to a real [http.Client].
class PhotonClient {
  final http.Client _client;
  final String userAgent;

  PhotonClient({required this.userAgent, http.Client? client})
      : _client = client ?? http.Client();

  /// Up to [limit] autocomplete matches for [query], biased toward [lat]/[lng]
  /// when given. Throws [ApiException] on a non-200 response.
  Future<List<GeoPlace>> suggest(String query, {double? lat, double? lng, int limit = 5}) async {
    final params = <String, String>{
      'q': query,
      'limit': '$limit',
      'lang': 'en',
    };
    if (lat != null && lng != null) {
      params['lat'] = '$lat';
      params['lon'] = '$lng';
    }
    final uri = Uri.https('photon.komoot.io', '/api/', params);
    final resp = await _client.get(uri, headers: {'User-Agent': userAgent});
    if (resp.statusCode != 200) {
      throw ApiException('Photon', resp.statusCode, resp.body);
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final features = (decoded['features'] as List?) ?? const [];
    return features
        .map((f) => _fromFeature(f as Map<String, dynamic>))
        .whereType<GeoPlace>()
        .toList();
  }

  /// Resolves the single best match (for an explicit search submission).
  Future<GeoPlace?> search(String query, {double? lat, double? lng}) async {
    final r = await suggest(query, lat: lat, lng: lng, limit: 1);
    return r.isEmpty ? null : r.first;
  }

  /// Photon returns GeoJSON; `geometry.coordinates` is `[lng, lat]`.
  static GeoPlace? _fromFeature(Map<String, dynamic> f) {
    final coords = (f['geometry'] as Map<String, dynamic>?)?['coordinates'] as List?;
    if (coords == null || coords.length < 2) return null;
    final props = (f['properties'] as Map<String, dynamic>?) ?? const {};
    return GeoPlace(
      lng: (coords[0] as num).toDouble(),
      lat: (coords[1] as num).toDouble(),
      label: _label(props),
    );
  }

  /// A readable label from Photon properties: "Name, street housenumber, city…".
  static String _label(Map<String, dynamic> p) {
    String? s(String k) {
      final v = p[k];
      return (v is String && v.isNotEmpty) ? v : null;
    }

    final street = [s('street'), s('housenumber')].whereType<String>().join(' ');
    final parts = <String>[
      if (s('name') != null) s('name')!,
      if (street.isNotEmpty) street,
      if (s('city') != null) s('city')!,
      if (s('state') != null) s('state')!,
      if (s('country') != null) s('country')!,
    ];
    return parts.isEmpty ? (s('name') ?? '') : parts.join(', ');
  }
}
