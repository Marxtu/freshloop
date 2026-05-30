import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_exception.dart';
import 'greenery_data.dart';

/// Client for the OSM Overpass API (design doc §5). Fetches green areas and
/// scenic POIs within a bounding box. Overpass requires a descriptive
/// User-Agent. Inject [client] in tests; defaults to a real [http.Client].
class OverpassClient {
  final http.Client _client;
  final String userAgent;

  OverpassClient({required this.userAgent, http.Client? client})
      : _client = client ?? http.Client();

  static final Uri _endpoint = Uri.parse('https://overpass-api.de/api/interpreter');

  /// Queries green/scenic features inside the bbox ([south],[west],[north],[east])
  /// and returns a [GreeneryData] count summary. Throws [ApiException] on non-200.
  Future<GreeneryData> fetchGreenery({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    final bbox = '$south,$west,$north,$east';
    final query = '[out:json][timeout:25];'
        '('
        'way["leisure"="park"]($bbox);'
        'way["landuse"~"forest|grass|meadow|recreation_ground|village_green"]($bbox);'
        'way["natural"~"wood|water|grassland|scrub"]($bbox);'
        'node["tourism"~"viewpoint|attraction"]($bbox);'
        'node["natural"="peak"]($bbox);'
        'node["historic"]($bbox);'
        ');out tags;';
    final resp = await _client.post(
      _endpoint,
      headers: {'User-Agent': userAgent},
      body: {'data': query},
    );
    if (resp.statusCode != 200) {
      throw ApiException('Overpass', resp.statusCode, resp.body);
    }
    return GreeneryData.fromOverpassJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }
}
