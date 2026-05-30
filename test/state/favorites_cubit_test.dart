import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/models/axis_score.dart';
import 'package:freshloop/domain/models/score_breakdown.dart';
import 'package:freshloop/domain/models/scored_route.dart';
import 'package:freshloop/services/favorites_repository.dart';
import 'package:freshloop/state/favorites_cubit.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('toggle adds then removes, exposing isFavorite', () async {
    final repo = SharedPrefsFavoritesRepository(await SharedPreferences.getInstance());
    final cubit = FavoritesCubit(repo);
    await cubit.load();
    final route = ScoredRoute(
      seed: 1,
      geometry: const RouteGeometry(points: [RoutePoint(lat: 45, lng: 9)], distanceM: 5000, ascentM: 40),
      score: ScoreBreakdown(air: AxisScore(80), hills: AxisScore(60), scenery: AxisScore(40), total: 60, explanation: 'x'),
    );

    await cubit.toggle(route);
    expect(cubit.isFavorite(route.routeKey), isTrue);
    expect(cubit.state.length, 1);

    await cubit.toggle(route);
    expect(cubit.isFavorite(route.routeKey), isFalse);
    expect(cubit.state, isEmpty);
    await cubit.close();
  });
}
