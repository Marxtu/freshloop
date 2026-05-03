import 'axis_score.dart';

/// The full, explainable score for one route candidate (design doc section 6).
class ScoreBreakdown {
  final AxisScore air;
  final AxisScore hills;
  final AxisScore scenery;
  final double total;
  final String explanation;

  ScoreBreakdown({
    required this.air,
    required this.hills,
    required this.scenery,
    required this.total,
    required this.explanation,
  });
}
