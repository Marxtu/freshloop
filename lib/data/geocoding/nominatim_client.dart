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
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'limit': '1',
    });
    final resp = await _client.get(uri, headers: {'User-Agent': userAgent});
    if (resp.statusCode != 200) {
      throw ApiException('Nominatim', resp.statusCode, resp.body);
    }
    final results = jsonDecode(resp.body) as List;
    if (results.isEmpty) return null;
    return GeoPlace.fromNominatimJson(results.first as Map<String, dynamic>);
  }
}
