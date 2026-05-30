import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/app/theme.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/models/axis_score.dart';
import 'package:freshloop/domain/models/score_breakdown.dart';
import 'package:freshloop/domain/models/scored_route.dart';
import 'package:freshloop/features/candidates/candidate_card.dart';

ScoredRoute _route() => ScoredRoute(
      seed: 1,
      geometry: const RouteGeometry(
        points: [RoutePoint(lat: 45.46, lng: 9.19), RoutePoint(lat: 45.47, lng: 9.20)],
        distanceM: 5000,
        ascentM: 40,
      ),
      score: ScoreBreakdown(
        air: AxisScore(80),
        hills: AxisScore(90),
        scenery: AxisScore(40),
        total: 72.3,
        explanation: 'Strong on air, hills; weak on scenery.',
      ),
    );

void main() {
  testWidgets('shows total, distance and the explanation', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: freshLoopTheme,
      home: Scaffold(body: CandidateCard(route: _route(), rank: 1, onTap: () {})),
    ));
    await tester.pump();
    expect(find.textContaining('72'), findsWidgets); // total score shown
    expect(find.textContaining('5.0 km'), findsOneWidget); // distance
    expect(find.textContaining('weak on scenery'), findsOneWidget);
  });
}
