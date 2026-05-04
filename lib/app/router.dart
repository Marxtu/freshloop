import 'package:go_router/go_router.dart';
import '../features/home/home_screen.dart';

/// Application routes. More routes are added as later feature plans land.
final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
  ],
);
