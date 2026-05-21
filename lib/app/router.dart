import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../domain/models/scored_route.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/candidates/candidates_screen.dart';
import '../features/detail/route_detail_screen.dart';
import '../features/home/home_screen.dart';
import '../features/saved/favorites_screen.dart';
import '../features/saved/history_screen.dart';
import '../features/tracking/tracking_screen.dart';
import '../services/location_source.dart';
import '../state/auth_cubit.dart';
import 'dependencies.dart';

/// Builds the app router. Built lazily (a function, not a top-level `final`) so
/// no Firebase singleton is read at library-load time — that would crash the
/// tests, which pump the app with Firebase uninitialized.
///
/// When [authGateEnabled] is true (Firebase mode, or a test injecting a fake
/// [AuthRepository]), the gate is driven by the in-scope [AuthCubit] state:
/// signed-out → `/sign-in`; signed-in & at `/sign-in` → `/`. This deliberately
/// reads the cubit, not `FirebaseAuth.instance`, so the gate works in tests
/// without a real Firebase app. When false (local mode), the redirect is a
/// no-op and the app behaves exactly as in M5.1.
GoRouter buildRouter({bool authGateEnabled = false, Listenable? refreshListenable}) {
  return GoRouter(
    refreshListenable: refreshListenable,
    redirect: authGateEnabled
        ? (context, state) {
            final auth = context.read<AuthCubit>().state;
            // While the first auth event is still resolving, don't redirect.
            if (auth.status == AuthStatus.unknown) return null;
            final signedIn = auth.status == AuthStatus.signedIn;
            final atSignIn = state.matchedLocation == '/sign-in';
            if (!signedIn && !atSignIn) return '/sign-in';
            if (signedIn && atSignIn) return '/';
            return null;
          }
        : null,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/sign-in', builder: (context, state) => const SignInScreen()),
      GoRoute(path: '/candidates', builder: (context, state) => const CandidatesScreen()),
      GoRoute(
        path: '/detail',
        builder: (context, state) => RouteDetailScreen(
          route: state.extra! as ScoredRoute,
          photoService: buildPhotoService(),
        ),
      ),
      GoRoute(
        path: '/tracking',
        builder: (context, state) => TrackingScreen(
          locationSource: const GeolocatorLocationSource(),
          planned: state.extra as ScoredRoute?,
        ),
      ),
      GoRoute(path: '/history', builder: (c, s) => HistoryScreen(repo: buildHistoryRepository())),
      GoRoute(path: '/favorites', builder: (c, s) => const FavoritesScreen()),
    ],
  );
}
