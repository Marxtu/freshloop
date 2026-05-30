import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/photos/scene_photo.dart';

void main() {
  group('ScenePhoto.fromMapillaryJson', () {
    test('parses thumb url and coordinates ([lng, lat])', () {
      final p = ScenePhoto.fromMapillaryJson({
        'id': '123',
        'thumb_256_url': 'https://img.example/256.jpg',
        'computed_geometry': {'type': 'Point', 'coordinates': [13.38, 52.51]},
      });
      expect(p.url, 'https://img.example/256.jpg');
      expect(p.source, PhotoSource.mapillary);
      expect(p.lng, 13.38);
      expect(p.lat, 52.51);
    });
  });

  group('ScenePhoto.fromWikimediaGeosearch', () {
    test('builds a Special:FilePath thumbnail url from the File title', () {
      final p = ScenePhoto.fromWikimediaGeosearch(
        {'title': 'File:Brandenburg Gate.jpg', 'lat': 52.5163, 'lon': 13.3777},
        width: 400,
      );
      expect(p.source, PhotoSource.wikimedia);
      expect(p.lat, 52.5163);
      expect(p.lng, 13.3777);
      expect(p.caption, 'Brandenburg Gate.jpg');
      expect(
        p.url,
        'https://commons.wikimedia.org/wiki/Special:FilePath/Brandenburg%20Gate.jpg?width=400',
      );
    });
  });
}
