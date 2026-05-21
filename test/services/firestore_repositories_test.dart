import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/models/axis_score.dart';
import 'package:freshloop/domain/models/run_record.dart';
import 'package:freshloop/domain/models/score_breakdown.dart';
import 'package:freshloop/domain/models/scored_route.dart';
import 'package:freshloop/services/firestore_favorites_repository.dart';
import 'package:freshloop/services/firestore_run_history_repository.dart';

ScoredRoute _route(int seed) => ScoredRoute(
      seed: seed,
      geometry: RouteGeometry(points: const [RoutePoint(lat: 45, lng: 9)], distanceM: 5000.0 + seed, ascentM: 40),
      score: ScoreBreakdown(air: AxisScore(80), hills: AxisScore(60), scenery: AxisScore(40), total: 60, explanation: 'x'),
    );

void main() {
  test('run history saves and lists under the user subtree', () async {
    final db = FakeFirebaseFirestore();
    final repo = FirestoreRunHistoryRepository(db, 'u1');
    await repo.save(const RunRecord(points: [], distanceM: 1000, durationS: 300));
    await repo.save(const RunRecord(points: [], distanceM: 2000, durationS: 600));
    final all = await repo.all();
    expect(all.length, 2);
    // isolation: another user sees nothing
    expect(await FirestoreRunHistoryRepository(db, 'u2').all(), isEmpty);
  });

  test('favourites add/list/isFavorite/remove by routeKey', () async {
    final db = FakeFirebaseFirestore();
    final repo = FirestoreFavoritesRepository(db, 'u1');
    final a = _route(1);
    await repo.add(a);
    await repo.add(a); // idempotent (same doc id)
    expect((await repo.all()).length, 1);
    expect(await repo.isFavorite(a.routeKey), isTrue);
    await repo.remove(a.routeKey);
    expect(await repo.all(), isEmpty);
    expect(await repo.isFavorite(a.routeKey), isFalse);
  });
}
