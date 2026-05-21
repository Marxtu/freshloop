import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/auth/auth_refresh.dart';
import '../services/auth_repository.dart';
import '../services/favorites_repository.dart';
import '../services/route_generator.dart';
import '../state/auth_cubit.dart';
import '../state/favorites_cubit.dart';
import '../state/route_gen_cubit.dart';
import 'dependencies.dart';
import 'router.dart';
import 'theme.dart';

class FreshLoopApp extends StatelessWidget {
  /// Inject a generator in tests; production builds one from real clients/keys.
  final RouteGenerator? generator;

  /// Inject a favourites repository in tests; production builds the app repo.
  final FavoritesRepository? favoritesRepository;

  /// Inject an auth repository in tests to drive the auth gate without a real
  /// Firebase app. When non-null (or [firebaseReady] is true) the app runs in
  /// Firebase mode; otherwise it stays in local (M5.1) mode.
  final AuthRepository? authRepository;

  const FreshLoopApp({
    super.key,
    this.generator,
    this.favoritesRepository,
    this.authRepository,
  });

  bool get _firebaseMode => firebaseReady || authRepository != null;

  @override
  Widget build(BuildContext context) {
    return _firebaseMode ? _FirebaseApp(parent: this) : _buildLocal();
  }

  /// Local mode: today's tree — no AuthCubit, no Firebase touched.
  Widget _buildLocal() {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => RouteGenCubit(generator ?? buildRouteGenerator())),
        BlocProvider(
          create: (_) => FavoritesCubit(favoritesRepository ?? buildFavoritesRepository())..load(),
        ),
      ],
      child: MaterialApp.router(
        title: 'FreshLoop',
        theme: freshLoopTheme,
        routerConfig: buildRouter(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Firebase mode: RouteGenCubit + AuthCubit above the router; the favourites
/// cubit is keyed on the signed-in uid so it rebinds to the right repository
/// when the user signs in/out. The router is built once with the auth gate
/// enabled and refreshes on each auth-state change.
class _FirebaseApp extends StatefulWidget {
  final FreshLoopApp parent;
  const _FirebaseApp({required this.parent});

  @override
  State<_FirebaseApp> createState() => _FirebaseAppState();
}

class _FirebaseAppState extends State<_FirebaseApp> {
  late final AuthCubit _authCubit;
  late final GoRouterRefreshStream _refresh;
  late final routerConfig = buildRouter(authGateEnabled: true, refreshListenable: _refresh);

  @override
  void initState() {
    super.initState();
    _authCubit = AuthCubit(widget.parent.authRepository ?? buildAuthRepository());
    _refresh = GoRouterRefreshStream(_authCubit.stream);
  }

  @override
  void dispose() {
    _refresh.dispose();
    _authCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parent = widget.parent;
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => RouteGenCubit(parent.generator ?? buildRouteGenerator())),
        BlocProvider.value(value: _authCubit),
      ],
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, auth) {
          final uid = auth.user?.uid;
          return KeyedSubtree(
            // Rebuild the favourites provider against the right repo on uid change.
            key: ValueKey(uid ?? '_out_'),
            child: BlocProvider(
              create: (_) =>
                  FavoritesCubit(parent.favoritesRepository ?? buildFavoritesRepository())..load(),
              child: MaterialApp.router(
                title: 'FreshLoop',
                theme: freshLoopTheme,
                routerConfig: routerConfig,
                debugShowCheckedModeBanner: false,
              ),
            ),
          );
        },
      ),
    );
  }
}
