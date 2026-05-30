import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/domain/scoring/air_score.dart';

void main() {
  group('airScore', () {
    test('lower mean AQI yields a higher score', () {
      expect(airScore([10, 20, 30]), 80);
    });
    test('clean air scores 100', () {
      expect(airScore([0]), 100);
    });
    test('very polluted air clamps to 0', () {
      expect(airScore([120]), 0);
    });
    test('empty samples throw ArgumentError', () {
      expect(() => airScore([]), throwsArgumentError);
    });
  });
}
