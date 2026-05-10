import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/domain/models/run_params.dart';
import 'package:freshloop/domain/models/score_weights.dart';

void main() {
  test('RunParams keeps inputs and defaults weights/ascent', () {
    const p = RunParams(startLat: 45.46, startLng: 9.19, targetDistanceM: 5000);
    expect(p.startLat, 45.46);
    expect(p.targetDistanceM, 5000);
    expect(p.targetAscentM, 0);
    expect(p.weights, isA<ScoreWeights>());
  });
}
