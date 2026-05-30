import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_exception.dart';
import 'scene_photo.dart';

/// Client for Wikimedia Commons geosearch (design doc §5). Finds geolocated
/// File: media near a point; thumbnails are derived from titles (see
/// [ScenePhoto.fromWikimediaGeosearch]). Requires a descriptive User-Agent.
class WikimediaPhotoClient {
  final http.Client _client;
  final String userAgent;

  WikimediaPhotoClient({required this.userAgent, http.Client? client})
      : _client = client ?? http.Client();

  /// Fetches up to [limit] geolocated photos within [radiusM] of ([lat],[lng]).
  /// Returns an empty list when none are found; throws [ApiException] on non-200.
  Future<List<ScenePhoto>> photosNear({
    required double lat,
    required double lng,
    int radiusM = 500,
    int limit = 5,
  }) async {
    final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
      'action': 'query',
      'list': 'geosearch',
      'gscoord': '$lat|$lng',
      'gsradius': '$radiusM',
      'gslimit': '$limit',
      'gsnamespace': '6',
      'format': 'json',
    });
    final resp = await _client.get(uri, headers: {'User-Agent': userAgent});
    if (resp.statusCode != 200) {
      throw ApiException('Wikimedia', resp.statusCode, resp.body);
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final results = ((decoded['query'] as Map<String, dynamic>?)?['geosearch'] as List?) ?? const [];
    return results
        .map((e) => ScenePhoto.fromWikimediaGeosearch(e as Map<String, dynamic>))
        .toList();
  }
}
