import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/domain/models/route_score_inputs.dart';
import 'package:freshloop/domain/models/score_weights.dart';
import 'package:freshloop/domain/models/tier.dart';
import 'package:freshloop/domain/scoring/route_scorer.dart';

const _scorer = RouteScorer();

RouteScoreInputs _inputs({
  List<double> aqi = const [20],
  double actual = 100,
  double target = 100,
  double green = 0.5,
  int waypoints = 3,
}) =>
    RouteScoreInputs(
      aqiSamples: aqi,
      actualAscentM: actual,
      targetAscentM: target,
      greenRatio: green,
      scenicWaypoints: waypoints,
    );

void main() {
  group('RouteScorer.score', () {
    test('computes each axis value and the weighted total', () {
      final b = _scorer.score(_inputs(), const ScoreWeights());
      expect(b.air.value, 80);
      expect(b.hills.value, 100);
      expect(b.scenery.value, 50);
      expect(b.total, 76.7);
    });

    test('weights shift the total', () {
      final b = _scorer.score(
        _inputs(),
        const ScoreWeights(air: 8, hills: 1, scenery: 1),
      );
      expect(b.total, 79.0);
    });

    test('explanation names good and poor axes', () {
      final b = _scorer.score(_inputs(green: 0, waypoints: 0), const ScoreWeights());
      expect(b.scenery.tier, Tier.poor);
      expect(b.explanation, 'Strong on air, hills; weak on scenery.');
    });
  });

  group('RouteScorer.rank', () {
    test('orders by total, highest first', () {
      final ranked = _scorer.rank<double>([40, 90, 70], (t) => t);
      expect(ranked, [90, 70, 40]);
    });
    test('is stable for equal totals (preserves input order)', () {
      final a = (id: 'a', total: 50.0);
      final b = (id: 'b', total: 50.0);
      final ranked = _scorer.rank([a, b], (t) => t.total);
      expect(ranked.map((e) => e.id).toList(), ['a', 'b']);
    });
  });
}
