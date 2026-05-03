import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/domain/scoring/scenery_score.dart';

void main() {
  group('sceneryScore', () {
    test('full greenery and 6+ waypoints scores 100', () {
      expect(sceneryScore(greenRatio: 1.0, scenicWaypoints: 6), 100);
    });
    test('waypoints are capped at 6', () {
      expect(sceneryScore(greenRatio: 1.0, scenicWaypoints: 10), 100);
    });
    test('half greenery and 3 waypoints scores 50', () {
      expect(sceneryScore(greenRatio: 0.5, scenicWaypoints: 3), 50);
    });
    test('no greenery and no waypoints scores 0', () {
      expect(sceneryScore(greenRatio: 0, scenicWaypoints: 0), 0);
    });
  });
}
