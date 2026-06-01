import '../../data/routing/route_geometry.dart';
import 'score_breakdown.dart';

/// How a candidate's shape was formed.
enum RouteKind {
  /// A single closed loop (ORS round-trip).
  loop,

  /// Out along a path and back the same way — clean and exactly on-distance
  /// even where the trail network is too sparse for a loop.
  outAndBack,
}

/// One generated candidate: its geometry and its explainable score. [seed] is
/// the ORS seed/bearing index that produced it (lets the UI request a fresh shape).
class ScoredRoute {
  final int seed;
  final RouteGeometry geometry;
  final ScoreBreakdown score;
  final RouteKind kind;

  const ScoredRoute({
    required this.seed,
    required this.geometry,
    required this.score,
    this.kind = RouteKind.loop,
  });

  /// Stable identity for favouriting (seed + rounded distance + start point).
  /// Used directly as a Firestore document ID, so it must stay a legal one:
  /// no '/', and never solely '.'/'..'. The current format (digits + '|',',','.')
  /// satisfies that — keep it that way if this ever changes.
  String get routeKey {
    final p = geometry.points.isEmpty ? '0,0' : '${geometry.points.first.lat},${geometry.points.first.lng}';
    return '$seed|${geometry.distanceM.round()}|$p';
  }

  Map<String, dynamic> toJson() => {
        'seed': seed,
        'geometry': geometry.toJson(),
        'score': score.toJson(),
        'kind': kind.name,
      };
  factory ScoredRoute.fromJson(Map<String, dynamic> j) => ScoredRoute(
        seed: (j['seed'] as num).toInt(),
        geometry: RouteGeometry.fromJson(j['geometry'] as Map<String, dynamic>),
        score: ScoreBreakdown.fromJson(j['score'] as Map<String, dynamic>),
        kind: RouteKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => RouteKind.loop, // older records had no kind
        ),
      );
}
