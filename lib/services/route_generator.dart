import '../data/air/open_meteo_air_client.dart';
import '../data/greenery/greenery_data.dart';
import '../data/greenery/overpass_client.dart';
import '../data/routing/ors_route_client.dart';
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
  Future<List<ScoredRoute>> generate(RunParams params, {int candidates = 3}) async {
    final scored = <ScoredRoute>[];
    for (var seed = 1; seed <= candidates; seed++) {
      final geometry = await ors.roundTrip(
        lat: params.startLat,
        lng: params.startLng,
        lengthM: params.targetDistanceM,
        seed: seed,
      );

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
        seed: seed,
        geometry: geometry,
        score: scorer.score(inputs, params.weights),
      ));
    }
    return scorer.rank(scored, (r) => r.score.total);
  }
}
