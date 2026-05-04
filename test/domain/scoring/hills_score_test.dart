import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/domain/scoring/hills_score.dart';

void main() {
  group('hillsScore', () {
    test('actual ascent equal to target scores 100', () {
      expect(hillsScore(actualAscentM: 100, targetAscentM: 100), 100);
    });
    test('diverging from a hilly target falls off linearly', () {
      expect(hillsScore(actualAscentM: 150, targetAscentM: 100), 50);
    });
    test('flat target met scores 100', () {
      expect(hillsScore(actualAscentM: 0, targetAscentM: 0), 100);
    });
    test('flat target with 50m ascent uses the 50m floor and scores 0', () {
      expect(hillsScore(actualAscentM: 50, targetAscentM: 0), 0);
    });
    test('half-way off a flat target scores 50', () {
      expect(hillsScore(actualAscentM: 25, targetAscentM: 0), 50);
    });
  });
}
