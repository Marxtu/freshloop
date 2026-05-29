import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_exception.dart';
import 'geo_place.dart';

/// Client for OSM Nominatim forward geocoding (design doc §5). Nominatim's usage
/// policy requires a descriptive User-Agent. Returns null when nothing matches.
class NominatimClient {
  final http.Client _client;
  final String userAgent;

  NominatimClient({required this.userAgent, http.Client? client})
      : _client = client ?? http.Client();

  Future<GeoPlace?> search(String query) async {
    final results = await suggest(query, limit: 1);
    return results.isEmpty ? null : results.first;
  }

  /// Returns up to [limit] matches for autocomplete. When [lat]/[lng] are given,
  /// a viewbox around them biases results toward nearby places (e.g. the nearest
  /// "Carrefour") without restricting to it.
  Future<List<GeoPlace>> suggest(String query, {double? lat, double? lng, int limit = 5}) async {
    final params = <String, String>{
      'q': query,
      'format': 'jsonv2',
      'limit': '$limit',
    };
    if (lat != null && lng != null) {
      const d = 0.15; // ~15 km bias box
      params['viewbox'] = '${lng - d},${lat - d},${lng + d},${lat + d}';
      params['bounded'] = '0'; // prefer the box, don't restrict to it
    }
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
    final resp = await _client.get(uri, headers: {'User-Agent': userAgent});
    if (resp.statusCode != 200) {
      throw ApiException('Nominatim', resp.statusCode, resp.body);
    }
    final results = jsonDecode(resp.body) as List;
    return results.map((e) => GeoPlace.fromNominatimJson(e as Map<String, dynamic>)).toList();
  }
}
