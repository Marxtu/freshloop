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

/// One generated geometry awaiting enrichment, with how it was formed.
typedef _Candidate = ({int seed, RouteGeometry geom, RouteKind kind});

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
    final start = RoutePoint(lat: params.startLat, lng: params.startLng);
    Object? lastError;

    // A round-trip loop (ORS picks the shape from a seed).
    Future<_Candidate?> fetchLoop(int seed) async {
      try {
        final g = await ors.roundTrip(
          lat: params.startLat,
          lng: params.startLng,
          lengthM: params.targetDistanceM,
          seed: seed,
        );
        return (seed: seed, geom: g, kind: RouteKind.loop);
      } catch (e) {
        lastError = e;
        return null;
      }
    }

    // An out-and-back: route to a turnaround ~half the distance away along a
    // bearing, then mirror the path home. Clean and exactly on-distance even
    // where the trail network is too sparse for a loop.
    Future<_Candidate?> fetchOutAndBack(int i, double bearing) async {
      final half = params.targetDistanceM / 2 / 1.3; // crow-flies, minus a typical detour
      final turn = destinationPoint(start, bearing, half);
      try {
        final leg = await ors.directions(
          fromLat: params.startLat,
          fromLng: params.startLng,
          toLat: turn.lat,
          toLng: turn.lng,
        );
        if (leg.points.length < 2) return null;
        final pts = [...leg.points, ...leg.points.reversed.skip(1)];
        final geom = RouteGeometry(points: pts, distanceM: leg.distanceM * 2, ascentM: ascentOf(pts));
        return (seed: 100 + i, geom: geom, kind: RouteKind.outAndBack);
      } catch (e) {
        lastError = e;
        return null;
      }
    }

    const bearings = [0.0, 90.0, 180.0, 270.0];
    final raw = await Future.wait(<Future<_Candidate?>>[
      for (var s = 1; s <= candidates * 2; s++) fetchLoop(s),
      for (var i = 0; i < bearings.length; i++) fetchOutAndBack(i, bearings[i]),
    ]);
    final pool = raw.whereType<_Candidate>().toList();
    if (pool.isEmpty) {
      throw lastError ?? StateError('No route could be generated');
    }
    // Keep the geometries closest to the requested distance (loop or out-and-back).
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
        kind: c.kind,
      ));
    }
    return scorer.rank(scored, (r) => r.score.total);
  }
}
