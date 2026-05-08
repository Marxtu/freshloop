import 'score_weights.dart';

/// What the user asked for: where to start, how far, the axis weights, and a
/// target cumulative ascent (0 = prefer flat). See design doc §8.
class RunParams {
  final double startLat;
  final double startLng;
  final double targetDistanceM;
  final ScoreWeights weights;
  final double targetAscentM;

  const RunParams({
    required this.startLat,
    required this.startLng,
    required this.targetDistanceM,
    this.weights = const ScoreWeights(),
    this.targetAscentM = 0,
  });
}
