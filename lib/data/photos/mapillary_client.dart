import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_exception.dart';
import 'scene_photo.dart';

/// Client for Mapillary street-level imagery (design doc §5). The token goes in
/// the `Authorization: OAuth <token>` header. Inject [client] in tests.
class MapillaryPhotoClient {
  final http.Client _client;
  final String accessToken;

  MapillaryPhotoClient({required this.accessToken, http.Client? client})
      : _client = client ?? http.Client();

  /// Fetches up to [limit] photos within the bbox. Throws [ApiException] on non-200.
  Future<List<ScenePhoto>> photosInBbox({
    required double south,
    required double west,
    required double north,
    required double east,
    int limit = 5,
  }) async {
    final uri = Uri.https('graph.mapillary.com', '/images', {
      'bbox': '$west,$south,$east,$north',
      'fields': 'id,thumb_256_url,computed_geometry',
      'limit': '$limit',
    });
    final resp = await _client.get(uri, headers: {'Authorization': 'OAuth $accessToken'});
    if (resp.statusCode != 200) {
      throw ApiException('Mapillary', resp.statusCode, resp.body);
    }
    final data = ((jsonDecode(resp.body) as Map<String, dynamic>)['data'] as List?) ?? const [];
    return data
        .map((e) => ScenePhoto.fromMapillaryJson(e as Map<String, dynamic>))
        .toList();
  }
}
