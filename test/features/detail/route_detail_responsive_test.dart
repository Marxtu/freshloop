import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:freshloop/app/theme.dart';
import 'package:freshloop/data/photos/scene_photo.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/models/axis_score.dart';
import 'package:freshloop/domain/models/score_breakdown.dart';
import 'package:freshloop/domain/models/scored_route.dart';
import 'package:freshloop/features/common/route_map.dart';
import 'package:freshloop/features/detail/route_detail_content.dart';
import 'package:freshloop/features/detail/route_detail_screen.dart';
import 'package:freshloop/services/favorites_repository.dart';
import 'package:freshloop/services/photo_service.dart';
import 'package:freshloop/state/favorites_cubit.dart';

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

/// A PhotoService that returns no photos, so the detail content resolves the
/// "Along the way" future without any network.
class _FakePhotoService implements PhotoService {
  @override
  Future<List<ScenePhoto>> photosForRoute(
    RouteGeometry geometry, {
    int maxWaypoints = 3,
    int perSource = 2,
  }) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// In-memory favourites so the favourite toggle has a cubit to read.
class _MemFavorites implements FavoritesRepository {
  final _routes = <ScoredRoute>[];
  @override
  Future<void> add(ScoredRoute route) async => _routes.add(route);
  @override
  Future<void> remove(String routeKey) async =>
      _routes.removeWhere((r) => r.routeKey == routeKey);
  @override
  Future<List<ScoredRoute>> all() async => List.of(_routes);
  @override
  Future<bool> isFavorite(String routeKey) async =>
      _routes.any((r) => r.routeKey == routeKey);
}

Widget _app(ScoredRoute route, Size size) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => MediaQuery(
          data: MediaQueryData(size: size),
          child: RouteDetailScreen(route: route, photoService: _FakePhotoService()),
        ),
      ),
      GoRoute(path: '/tracking', builder: (context, state) => const SizedBox()),
    ],
  );
  return BlocProvider<FavoritesCubit>(
    create: (_) => FavoritesCubit(_MemFavorites())..load(),
    child: MaterialApp.router(theme: freshLoopTheme, routerConfig: router),
  );
}

void main() {
  testWidgets('wide: map and detail content are visible side by side', (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_route(), const Size(1100, 800)));
    await tester.pump();

    expect(find.byType(RouteMap), findsOneWidget);
    expect(find.byType(RouteDetailContent), findsOneWidget);
    expect(find.text('Start run'), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    // The favourite toggle is reachable in the wide layout.
    expect(find.byTooltip('Save to favourites'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('narrow: detail rides in a draggable sheet', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_route(), const Size(400, 800)));
    await tester.pump();

    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.byType(RouteMap), findsOneWidget);
    expect(find.byType(RouteDetailContent), findsOneWidget);
    expect(find.byTooltip('Save to favourites'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });
}
