import '../../data/routing/route_geometry.dart';
import 'score_breakdown.dart';

/// One generated candidate: its geometry and its explainable score. [seed] is
/// the ORS round-trip seed that produced it (lets the UI request a fresh shape).
class ScoredRoute {
  final int seed;
  final RouteGeometry geometry;
  final ScoreBreakdown score;

  const ScoredRoute({required this.seed, required this.geometry, required this.score});
}
