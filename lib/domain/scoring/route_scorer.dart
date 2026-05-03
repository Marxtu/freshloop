import '../models/axis_score.dart';
import '../models/route_score_inputs.dart';
import '../models/score_breakdown.dart';
import '../models/score_weights.dart';
import '../models/tier.dart';
import 'air_score.dart';
import 'hills_score.dart';
import 'scenery_score.dart';

/// Combines the three axis sub-scores into an explainable [ScoreBreakdown].
/// Pure functions — no Flutter, no I/O — so they unit-test cleanly
/// (design doc section 6).
class RouteScorer {
  const RouteScorer();

  ScoreBreakdown score(RouteScoreInputs inputs, ScoreWeights weights) {
    final air = AxisScore(airScore(inputs.aqiSamples));
    final hills = AxisScore(hillsScore(
      actualAscentM: inputs.actualAscentM,
      targetAscentM: inputs.targetAscentM,
    ));
    final scenery = AxisScore(sceneryScore(
      greenRatio: inputs.greenRatio,
      scenicWaypoints: inputs.scenicWaypoints,
    ));

    final w = weights.normalized();
    final rawTotal = air.value * w.air + hills.value * w.hills + scenery.value * w.scenery;

    return ScoreBreakdown(
      air: air,
      hills: hills,
      scenery: scenery,
      total: double.parse(rawTotal.toStringAsFixed(1)),
      explanation: _explain(air, hills, scenery),
    );
  }

  /// Builds a one-line, deterministic explanation from the per-axis tiers.
  /// Axis order is fixed (air, hills, scenery) so the text is stable.
  String _explain(AxisScore air, AxisScore hills, AxisScore scenery) {
    final byAxis = <String, Tier>{
      'air': air.tier,
      'hills': hills.tier,
      'scenery': scenery.tier,
    };
    final strengths = byAxis.entries.where((e) => e.value == Tier.good).map((e) => e.key).toList();
    final weaknesses = byAxis.entries.where((e) => e.value == Tier.poor).map((e) => e.key).toList();

    final parts = <String>[];
    if (strengths.isNotEmpty) parts.add('Strong on ${strengths.join(', ')}');
    if (weaknesses.isNotEmpty) parts.add('weak on ${weaknesses.join(', ')}');
    if (parts.isEmpty) return 'A balanced route.';
    return '${parts.join('; ')}.';
  }
}
