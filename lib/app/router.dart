import 'package:go_router/go_router.dart';
import '../features/home/home_screen.dart';
import '../features/candidates/candidates_screen.dart';

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/candidates', builder: (context, state) => const CandidatesScreen()),
  ],
);
