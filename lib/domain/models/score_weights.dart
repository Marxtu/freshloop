/// Relative importance of each scoring axis, set by the user on the params
/// screen (M3). Weights are normalized before use, so any non-negative values
/// are valid input.
class ScoreWeights {
  final double air;
  final double hills;
  final double scenery;

  const ScoreWeights({this.air = 1, this.hills = 1, this.scenery = 1});

  double get _sum => air + hills + scenery;

  /// Normalized weights that sum to 1. Falls back to equal thirds if all zero.
  ScoreWeights normalized() {
    if (_sum == 0) {
      return const ScoreWeights(air: 1 / 3, hills: 1 / 3, scenery: 1 / 3);
    }
    return ScoreWeights(air: air / _sum, hills: hills / _sum, scenery: scenery / _sum);
  }
}
