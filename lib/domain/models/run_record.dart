import '../../data/routing/route_geometry.dart';

/// A completed (or in-progress snapshot of a) run: the GPS trail, total
/// distance, and elapsed time. See design doc §8.
class RunRecord {
  final List<RoutePoint> points;
  final double distanceM;
  final int durationS;

  const RunRecord({required this.points, required this.distanceM, required this.durationS});

  /// Average pace in seconds per kilometre (0 when no distance was covered).
  double get paceSecPerKm => distanceM <= 0 ? 0 : durationS / (distanceM / 1000);
}
