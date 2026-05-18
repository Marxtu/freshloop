import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/models/axis_score.dart';
import 'package:freshloop/domain/models/score_breakdown.dart';
import 'package:freshloop/domain/models/scored_route.dart';
import 'package:freshloop/services/favorites_repository.dart';

ScoredRoute _route(int seed) => ScoredRoute(
      seed: seed,
      geometry: RouteGeometry(points: const [RoutePoint(lat: 45, lng: 9)], distanceM: 5000.0 + seed, ascentM: 40),
      score: ScoreBreakdown(air: AxisScore(80), hills: AxisScore(60), scenery: AxisScore(40), total: 60, explanation: 'x'),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('adds, lists, checks, and removes favourites', () async {
    final repo = SharedPrefsFavoritesRepository(await SharedPreferences.getInstance());
    final a = _route(1);
    await repo.add(a);
    expect((await repo.all()).length, 1);
    expect(await repo.isFavorite(a.routeKey), isTrue);
    await repo.remove(a.routeKey);
    expect(await repo.all(), isEmpty);
    expect(await repo.isFavorite(a.routeKey), isFalse);
  });
}
