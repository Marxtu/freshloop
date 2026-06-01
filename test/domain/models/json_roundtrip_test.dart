import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/models/axis_score.dart';
import 'package:freshloop/domain/models/run_record.dart';
import 'package:freshloop/domain/models/score_breakdown.dart';
import 'package:freshloop/domain/models/scored_route.dart';

void main() {
  test('RouteGeometry JSON round-trips', () {
    const g = RouteGeometry(
      points: [RoutePoint(lat: 1, lng: 2, elevation: 3), RoutePoint(lat: 4, lng: 5)],
      distanceM: 100, ascentM: 10,
    );
    final r = RouteGeometry.fromJson(g.toJson());
    expect(r.points.length, 2);
    expect(r.points.first.elevation, 3);
    expect(r.points[1].elevation, isNull);
    expect(r.distanceM, 100);
    expect(r.ascentM, 10);
  });

  test('ScoredRoute JSON round-trips and keeps a stable routeKey', () {
    final route = ScoredRoute(
      seed: 2,
      geometry: const RouteGeometry(points: [RoutePoint(lat: 45.4, lng: 9.1)], distanceM: 5000, ascentM: 40),
      score: ScoreBreakdown(air: AxisScore(80), hills: AxisScore(60), scenery: AxisScore(40), total: 61.0, explanation: 'x'),
    );
    final r = ScoredRoute.fromJson(route.toJson());
    expect(r.seed, 2);
    expect(r.score.total, 61.0);
    expect(r.score.air.value, 80);
    expect(r.routeKey, route.routeKey);
    expect(r.kind, RouteKind.loop); // default when unspecified
  });

  test('ScoredRoute round-trips its kind, and tolerates older records', () {
    final ob = ScoredRoute(
      seed: 1,
      geometry: const RouteGeometry(points: [RoutePoint(lat: 45.4, lng: 9.1)], distanceM: 5000, ascentM: 40),
      score: ScoreBreakdown(air: AxisScore(80), hills: AxisScore(60), scenery: AxisScore(40), total: 61.0, explanation: 'x'),
      kind: RouteKind.outAndBack,
    );
    expect(ScoredRoute.fromJson(ob.toJson()).kind, RouteKind.outAndBack);
    // a record saved before 'kind' existed falls back to loop
    expect(
      ScoredRoute.fromJson({
        'seed': 1,
        'geometry': const RouteGeometry(points: [RoutePoint(lat: 1, lng: 2)], distanceM: 1, ascentM: 0).toJson(),
        'score': ScoreBreakdown(air: AxisScore(1), hills: AxisScore(1), scenery: AxisScore(1), total: 1, explanation: 'x').toJson(),
      }).kind,
      RouteKind.loop,
    );
  });

  test('RunRecord JSON round-trips', () {
    const rec = RunRecord(points: [RoutePoint(lat: 1, lng: 2)], distanceM: 2000, durationS: 600);
    final r = RunRecord.fromJson(rec.toJson());
    expect(r.distanceM, 2000);
    expect(r.durationS, 600);
    expect(r.points.length, 1);
    expect(r.startedAt, isNull); // omitted when absent
  });

  test('RunRecord round-trips its startedAt, and tolerates older records', () {
    final rec = RunRecord(
      points: const [RoutePoint(lat: 1, lng: 2)],
      distanceM: 2000,
      durationS: 600,
      startedAt: DateTime(2026, 5, 28, 14, 32),
    );
    expect(RunRecord.fromJson(rec.toJson()).startedAt, DateTime(2026, 5, 28, 14, 32));
    // a record stored before this field existed has no 'startedAt' key
    expect(
      RunRecord.fromJson({'points': const [], 'distanceM': 1, 'durationS': 1}).startedAt,
      isNull,
    );
  });
}
