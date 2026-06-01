import '../data/air/open_meteo_air_client.dart';
import '../data/greenery/greenery_data.dart';
import '../data/greenery/overpass_client.dart';
import '../data/routing/ors_route_client.dart';
import '../data/routing/route_geometry.dart';
import '../domain/geo.dart';
import '../domain/models/route_score_inputs.dart';
import '../domain/models/run_params.dart';
import '../domain/models/scored_route.dart';
import '../domain/scoring/route_scorer.dart';

/// Orchestrates the data clients and the scorer to produce ranked candidates.
/// Enrichment failures (air/greenery) degrade to neutral values so a route is
/// still scored (design doc §11); a routing failure propagates (no route, no run).
class RouteGenerator {
  final OrsRouteClient ors;
  final OpenMeteoAirClient air;
  final OverpassClient overpass;
  final RouteScorer scorer;

  RouteGenerator({
    required this.ors,
    required this.air,
    required this.overpass,
    this.scorer = const RouteScorer(),
  });

  /// Generates [candidates] loop routes for [params] and returns them ranked
  /// best-first. Neutral AQI (50) is used if air data is unavailable.
  ///
  /// ORS `round_trip` can deviate a lot from the requested length where the
  /// foot network is sparse (e.g. alpine valleys). So we **over-generate** a
  /// pool of cheap geometries and keep the [candidates] whose length is closest
  /// to the target before doing the (heavier) enrichment + scoring.
  Future<List<ScoredRoute>> generate(RunParams params, {int candidates = 3}) async {
    Object? lastError;
    Future<({int seed, RouteGeometry geom})?> fetch(int seed) async {
      try {
        final g = await ors.roundTrip(
          lat: params.startLat,
          lng: params.startLng,
          lengthM: params.targetDistanceM,
          seed: seed,
        );
        return (seed: seed, geom: g);
      } catch (e) {
        lastError = e;
        return null;
      }
    }

    final raw = await Future.wait([for (var s = 1; s <= candidates * 2; s++) fetch(s)]);
    final pool = raw.whereType<({int seed, RouteGeometry geom})>().toList();
    if (pool.isEmpty) {
      throw lastError ?? StateError('No route could be generated');
    }
    // Keep the geometries closest to the requested distance.
    pool.sort((a, b) => (a.geom.distanceM - params.targetDistanceM)
        .abs()
        .compareTo((b.geom.distanceM - params.targetDistanceM).abs()));
    final chosen = pool.take(candidates).toList();

    final scored = <ScoredRoute>[];
    for (final c in chosen) {
      final geometry = c.geom;
      List<double> aqi;
      try {
        aqi = await air.sampleAqi(subsample(geometry.points, 10));
      } catch (_) {
        aqi = const [];
      }

      GreeneryData greenery;
      try {
        final b = boundingBoxOf(geometry.points);
        greenery = await overpass.fetchGreenery(
          south: b.south,
          west: b.west,
          north: b.north,
          east: b.east,
        );
      } catch (_) {
        greenery = const GreeneryData(greenCount: 0, scenicCount: 0);
      }

      final inputs = RouteScoreInputs(
        aqiSamples: aqi.isEmpty ? const [50.0] : aqi,
        actualAscentM: geometry.ascentM,
        targetAscentM: params.targetAscentM,
        greenRatio: greenery.greenRatio,
        scenicWaypoints: greenery.scenicWaypoints,
      );

      scored.add(ScoredRoute(
        seed: c.seed,
        geometry: geometry,
        score: scorer.score(inputs, params.weights),
      ));
    }
    return scorer.rank(scored, (r) => r.score.total);
  }
}
