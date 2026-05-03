/// Air-quality sub-score: lower AQI along the route yields a higher score.
///
/// [aqiSamples] are European AQI values sampled along the route (lower is
/// better). Returns a 0-100 score. Throws [ArgumentError] if empty.
double airScore(List<double> aqiSamples) {
  if (aqiSamples.isEmpty) {
    throw ArgumentError('aqiSamples must not be empty');
  }
  final mean = aqiSamples.reduce((a, b) => a + b) / aqiSamples.length;
  return (100 - mean).clamp(0, 100).toDouble();
}
