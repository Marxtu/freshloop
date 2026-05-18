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

  Map<String, dynamic> toJson() => {
        'air': air.value, 'hills': hills.value, 'scenery': scenery.value,
        'total': total, 'explanation': explanation,
      };
  factory ScoreBreakdown.fromJson(Map<String, dynamic> j) => ScoreBreakdown(
        air: AxisScore((j['air'] as num).toDouble()),
        hills: AxisScore((j['hills'] as num).toDouble()),
        scenery: AxisScore((j['scenery'] as num).toDouble()),
        total: (j['total'] as num).toDouble(),
        explanation: j['explanation'] as String,
      );
}
