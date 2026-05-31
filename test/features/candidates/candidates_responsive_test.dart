import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:freshloop/app/theme.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/models/axis_score.dart';
import 'package:freshloop/domain/models/score_breakdown.dart';
import 'package:freshloop/domain/models/scored_route.dart';
import 'package:freshloop/features/candidates/candidate_card.dart';
import 'package:freshloop/features/candidates/candidates_screen.dart';
import 'package:freshloop/services/route_generator.dart';
import 'package:freshloop/state/route_gen_cubit.dart';
import 'package:freshloop/state/route_gen_state.dart';

ScoredRoute _route(int seed) => ScoredRoute(
      seed: seed,
      geometry: RouteGeometry(
        points: [
          RoutePoint(lat: 45.46 + seed * 0.001, lng: 9.19),
          RoutePoint(lat: 45.47 + seed * 0.001, lng: 9.20),
        ],
        distanceM: 5000 + seed * 100,
        ascentM: 40,
      ),
      score: ScoreBreakdown(
        air: AxisScore(80),
        hills: AxisScore(90),
        scenery: AxisScore(40),
        total: 70 + seed.toDouble(),
        explanation: 'Route $seed explanation.',
      ),
    );

/// A RouteGenCubit seeded directly into a loaded state for layout tests, so we
/// never run the (network-touching) generator.
class _SeededCubit extends RouteGenCubit {
  _SeededCubit(List<ScoredRoute> routes)
      : super(_NeverGenerator()) {
    emit(RouteGenLoaded(routes));
  }
}

class _NeverGenerator implements RouteGenerator {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('generator should not be called in a layout test');
}

Widget _app(List<ScoredRoute> routes, Size size) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => BlocProvider<RouteGenCubit>(
          create: (_) => _SeededCubit(routes),
          child: const CandidatesScreen(),
        ),
      ),
      // /detail is referenced by the cards' onTap; a stub keeps push() valid.
      GoRoute(path: '/detail', builder: (context, state) => const SizedBox()),
    ],
  );
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp.router(theme: freshLoopTheme, routerConfig: router),
  );
}

void main() {
  testWidgets('renders a grid with all cards on a wide screen', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final routes = [_route(1), _route(2), _route(3)];
    await tester.pumpWidget(_app(routes, const Size(1000, 800)));
    await tester.pump();

    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(CandidateCard), findsNWidgets(3));
  });

  testWidgets('renders a list on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final routes = [_route(1), _route(2), _route(3)];
    await tester.pumpWidget(_app(routes, const Size(400, 800)));
    await tester.pump();

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
    // The list builds lazily, so only the on-screen cards are present; assert
    // at least the first renders without overflow.
    expect(find.byType(CandidateCard), findsAtLeastNWidgets(1));
  });
}
