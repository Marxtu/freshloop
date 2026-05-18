import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/favorites_repository.dart';
import '../services/route_generator.dart';
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
  const FreshLoopApp({super.key, this.generator, this.favoritesRepository});

  @override
  Widget build(BuildContext context) {
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
        routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
