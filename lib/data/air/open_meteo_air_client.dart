import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_exception.dart';
import '../routing/route_geometry.dart';

/// Client for the Open-Meteo Air Quality API (design doc §5). Returns the
/// European AQI sampled at each given point (lower is better). Keyless.
/// Inject [client] in tests; defaults to a real [http.Client].
class OpenMeteoAirClient {
  final http.Client _client;

  OpenMeteoAirClient({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches the current European AQI at each of [points], aligned by index.
  /// Returns an empty list (no network call) when [points] is empty.
  /// Throws [ApiException] on a non-200 response.
  Future<List<double>> sampleAqi(List<RoutePoint> points) async {
    if (points.isEmpty) return const [];
    final uri = Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
      'latitude': points.map((p) => p.lat).join(','),
      'longitude': points.map((p) => p.lng).join(','),
      'current': 'european_aqi',
    });
    final resp = await _client.get(uri);
    if (resp.statusCode != 200) {
      throw ApiException('Open-Meteo Air', resp.statusCode, resp.body);
    }
    final decoded = jsonDecode(resp.body);
    // Multiple coords -> array; single coord -> object. Normalize to a list.
    final list = decoded is List ? decoded : [decoded];
    return list
        .map((e) => ((e as Map<String, dynamic>)['current']
            as Map<String, dynamic>)['european_aqi'] as num)
        .map((n) => n.toDouble())
        .toList();
  }
}
