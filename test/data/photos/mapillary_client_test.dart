import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:freshloop/data/api_exception.dart';
import 'package:freshloop/data/photos/mapillary_client.dart';
import 'package:freshloop/data/photos/scene_photo.dart';

void main() {
  group('MapillaryPhotoClient.photosInBbox', () {
    test('sends OAuth header + bbox, prefers 1024px, orders perspective before panoramas', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': '2',
                'is_pano': true, // 360° panorama listed first…
                'thumb_original_url': 'https://img/2_original.jpg',
                'thumb_2048_url': 'https://img/2_2048.jpg',
                'thumb_1024_url': 'https://img/2_1024.jpg',
                'computed_geometry': {'coordinates': [13.39, 52.52]},
              },
              {
                'id': '1',
                'is_pano': false, // …perspective shot should sort ahead of it
                'thumb_1024_url': 'https://img/1_1024.jpg',
                'thumb_256_url': 'https://img/1_256.jpg',
                'computed_geometry': {'coordinates': [13.38, 52.51]},
              },
            ],
          }),
          200,
        );
      });
      final client = MapillaryPhotoClient(accessToken: 'MLY|x|y', client: mock);

      final photos = await client.photosInBbox(south: 52.5, west: 13.3, north: 52.6, east: 13.4, limit: 5);

      expect(photos.length, 2); // panorama kept as fallback, not dropped
      expect(photos.first.url, 'https://img/1_1024.jpg'); // perspective first, 1024 preferred
      expect(photos.first.isPano, isFalse);
      expect(photos[1].isPano, isTrue); // panorama sorted last
      // a panorama wraps the whole sphere, so it exposes the ORIGINAL full-res
      // image for the viewer (2048px is still too soft at 360°)
      expect(photos[1].fullUrl, 'https://img/2_original.jpg');
      // a perspective shot is crisp at 2048px and uses that (no heavy original)
      expect(photos.first.fullUrl, 'https://img/1_1024.jpg'); // (no 2048 in fixture → 1024)
      expect(photos.first.source, PhotoSource.mapillary);
      expect(captured.headers['Authorization'], 'OAuth MLY|x|y');
      // requests the original + 2048px fields so the full-screen viewer is sharp
      expect(captured.url.queryParameters['fields'], contains('thumb_original_url'));
      expect(captured.url.queryParameters['fields'], contains('thumb_2048_url'));
      // Mapillary bbox order is west,south,east,north
      expect(captured.url.queryParameters['bbox'], '13.3,52.5,13.4,52.6');
      // over-fetches (limit * 4) so perspective shots can be prioritised
      expect(captured.url.queryParameters['limit'], '20');
    });

    test('returns empty list when data is empty', () async {
      final mock = MockClient((req) async => http.Response(jsonEncode({'data': []}), 200));
      final client = MapillaryPhotoClient(accessToken: 't', client: mock);
      expect(await client.photosInBbox(south: 0, west: 0, north: 1, east: 1), isEmpty);
    });

    test('throws ApiException on non-200', () async {
      final mock = MockClient((req) async => http.Response('err', 500));
      final client = MapillaryPhotoClient(accessToken: 't', client: mock);
      expect(
        () => client.photosInBbox(south: 0, west: 0, north: 1, east: 1),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
