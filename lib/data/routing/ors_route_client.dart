import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_exception.dart';
import 'route_geometry.dart';

/// Client for OpenRouteService round-trip foot routing (design doc §5).
/// Inject [client] in tests; defaults to a real [http.Client] in production.
class OrsRouteClient {
  final http.Client _client;
  final String apiKey;

  OrsRouteClient({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  static final Uri _endpoint =
      Uri.parse('https://api.openrouteservice.org/v2/directions/foot-walking/geojson');

  /// Generates a loop of roughly [lengthM] metres starting and ending at
  /// ([lat], [lng]). [seed] varies the generated shape so callers can request
  /// several distinct candidates. Throws [ApiException] on a non-200 response.
  Future<RouteGeometry> roundTrip({
    required double lat,
    required double lng,
    required double lengthM,
    int seed = 1,
  }) async {
    if (apiKey.isEmpty) {
      throw ApiException('OpenRouteService', 401,
          'API key missing — build/run with --dart-define-from-file=secrets.json');
    }
    final resp = await _client.post(
      _endpoint,
      headers: {
        'Authorization': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'coordinates': [
          [lng, lat],
        ],
        'elevation': true,
        'options': {
          'round_trip': {'length': lengthM, 'points': 5, 'seed': seed},
        },
      }),
    );
    if (resp.statusCode != 200) {
      throw ApiException('OpenRouteService', resp.statusCode, resp.body);
    }
    return RouteGeometry.fromOrsGeoJson(
      jsonDecode(resp.body) as Map<String, dynamic>,
    );
  }

  /// Point-to-point foot route from ([fromLat],[fromLng]) to ([toLat],[toLng]).
  /// Used to build clean out-and-back routes (route there, then mirror it back).
  /// Throws [ApiException] on a non-200 response.
  Future<RouteGeometry> directions({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    if (apiKey.isEmpty) {
      throw ApiException('OpenRouteService', 401,
          'API key missing — build/run with --dart-define-from-file=secrets.json');
    }
    final resp = await _client.post(
      _endpoint,
      headers: {
        'Authorization': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'coordinates': [
          [fromLng, fromLat],
          [toLng, toLat],
        ],
        'elevation': true,
      }),
    );
    if (resp.statusCode != 200) {
      throw ApiException('OpenRouteService', resp.statusCode, resp.body);
    }
    return RouteGeometry.fromOrsGeoJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }
}
