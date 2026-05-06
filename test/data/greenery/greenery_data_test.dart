import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/greenery/greenery_data.dart';

void main() {
  group('GreeneryData.fromOverpassJson', () {
    test('counts green features and scenic POIs by tag', () {
      final json = {
        'elements': [
          {'type': 'way', 'tags': {'leisure': 'park'}},
          {'type': 'way', 'tags': {'landuse': 'forest'}},
          {'type': 'way', 'tags': {'natural': 'water'}},
          {'type': 'node', 'tags': {'tourism': 'viewpoint'}},
          {'type': 'node', 'tags': {'historic': 'monument'}},
          {'type': 'node', 'tags': {'amenity': 'bench'}}, // neither
        ],
      };
      final g = GreeneryData.fromOverpassJson(json);
      expect(g.greenCount, 3); // park, forest, water
      expect(g.scenicCount, 2); // viewpoint, monument(historic)
    });

    test('greenRatio normalizes against 8 and clamps to 1', () {
      expect(const GreeneryData(greenCount: 0, scenicCount: 0).greenRatio, 0);
      expect(const GreeneryData(greenCount: 4, scenicCount: 1).greenRatio, 0.5);
      expect(const GreeneryData(greenCount: 8, scenicCount: 0).greenRatio, 1);
      expect(const GreeneryData(greenCount: 20, scenicCount: 0).greenRatio, 1);
    });

    test('scenicWaypoints passes the scenic count through', () {
      expect(const GreeneryData(greenCount: 0, scenicCount: 3).scenicWaypoints, 3);
    });

    test('handles missing elements key', () {
      final g = GreeneryData.fromOverpassJson(const {});
      expect(g.greenCount, 0);
      expect(g.scenicCount, 0);
    });
  });
}
