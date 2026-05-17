// Mock data for local screenshot previews only (not shipped, not tested).
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/models/axis_score.dart';
import 'package:freshloop/domain/models/score_breakdown.dart';
import 'package:freshloop/domain/models/scored_route.dart';

const loop = [
  RoutePoint(lat: 45.4720, lng: 9.1740, elevation: 122),
  RoutePoint(lat: 45.4745, lng: 9.1760, elevation: 131),
  RoutePoint(lat: 45.4738, lng: 9.1800, elevation: 126),
  RoutePoint(lat: 45.4710, lng: 9.1795, elevation: 119),
  RoutePoint(lat: 45.4705, lng: 9.1755, elevation: 121),
  RoutePoint(lat: 45.4720, lng: 9.1740, elevation: 122),
];

final ScoredRoute mockRoute = ScoredRoute(
  seed: 1,
  geometry: const RouteGeometry(points: loop, distanceM: 5200, ascentM: 64),
  score: ScoreBreakdown(
    air: AxisScore(86), hills: AxisScore(78), scenery: AxisScore(72),
    total: 79.3, explanation: 'Strong on air, hills; mostly through the park.',
  ),
);
