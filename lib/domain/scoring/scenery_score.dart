/// Scenery sub-score from greenery coverage and scenic waypoints.
///
/// [greenRatio] is the fraction (0..1) of the route buffer covered by parks or
/// water. [scenicWaypoints] counts notable points passed (capped at 6).
/// Coverage contributes up to 70 points, waypoints up to 30.
double sceneryScore({required double greenRatio, required int scenicWaypoints}) {
  final coverage = greenRatio.clamp(0, 1) * 70;
  final capped = scenicWaypoints > 6 ? 6 : scenicWaypoints;
  final waypointPoints = (capped / 6) * 30;
  return (coverage + waypointPoints).clamp(0, 100).toDouble();
}
