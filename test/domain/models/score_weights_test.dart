import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/domain/models/score_weights.dart';

void main() {
  group('ScoreWeights.normalized', () {
    test('equal weights normalize to one third each', () {
      final n = const ScoreWeights().normalized();
      expect(n.air, closeTo(1 / 3, 1e-9));
      expect(n.hills, closeTo(1 / 3, 1e-9));
      expect(n.scenery, closeTo(1 / 3, 1e-9));
    });
    test('weights normalize to sum to 1', () {
      final n = const ScoreWeights(air: 2, hills: 1, scenery: 1).normalized();
      expect(n.air + n.hills + n.scenery, closeTo(1.0, 1e-9));
      expect(n.air, closeTo(0.5, 1e-9));
    });
    test('all-zero weights fall back to equal thirds', () {
      final n = const ScoreWeights(air: 0, hills: 0, scenery: 0).normalized();
      expect(n.air, closeTo(1 / 3, 1e-9));
    });
  });
}
