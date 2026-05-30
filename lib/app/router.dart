import 'package:go_router/go_router.dart';
import '../domain/models/scored_route.dart';
import '../features/home/home_screen.dart';
import '../features/candidates/candidates_screen.dart';
import '../features/detail/route_detail_screen.dart';
import 'dependencies.dart';

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/candidates', builder: (context, state) => const CandidatesScreen()),
    GoRoute(
      path: '/detail',
      builder: (context, state) => RouteDetailScreen(
        route: state.extra! as ScoredRoute,
        photoService: buildPhotoService(),
      ),
    ),
  ],
);
