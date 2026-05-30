import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/routing/route_geometry.dart';

void main() {
  group('RouteGeometry.fromOrsGeoJson', () {
    final json = {
      'features': [
        {
          'geometry': {
            'coordinates': [
              [8.681, 49.414, 110.0],
              [8.682, 49.415, 115.0],
              [8.681, 49.414, 110.0],
            ],
          },
          'properties': {
            'ascent': 42.0,
            'summary': {'distance': 5012.3, 'duration': 3600.0},
          },
        },
      ],
    };

    test('parses points (lng,lat,elev), distance and ascent', () {
      final g = RouteGeometry.fromOrsGeoJson(json);
      expect(g.points.length, 3);
      expect(g.points.first.lat, 49.414);
      expect(g.points.first.lng, 8.681);
      expect(g.points.first.elevation, 110.0);
      expect(g.distanceM, 5012.3);
      expect(g.ascentM, 42.0);
    });

    test('defaults ascent to 0 when absent', () {
      final j = {
        'features': [
          {
            'geometry': {'coordinates': [[8.0, 49.0]]},
            'properties': {'summary': {'distance': 100.0}},
          },
        ],
      };
      final g = RouteGeometry.fromOrsGeoJson(j);
      expect(g.ascentM, 0);
      expect(g.points.single.elevation, isNull);
    });

    test('throws FormatException when no features', () {
      expect(() => RouteGeometry.fromOrsGeoJson({'features': []}), throwsFormatException);
    });
  });
}
