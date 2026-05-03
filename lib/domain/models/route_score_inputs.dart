/// Raw measured inputs for scoring one route candidate. Kept separate from how
/// the data was fetched (the M2 API layer) so scoring stays a pure function.
class RouteScoreInputs {
  final List<double> aqiSamples;
  final double actualAscentM;
  final double targetAscentM;
  final double greenRatio;
  final int scenicWaypoints;

  const RouteScoreInputs({
    required this.aqiSamples,
    required this.actualAscentM,
    required this.targetAscentM,
    required this.greenRatio,
    required this.scenicWaypoints,
  });
}
