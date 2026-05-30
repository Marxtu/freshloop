import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/route_generator.dart';
import '../state/route_gen_cubit.dart';
import 'dependencies.dart';
import 'router.dart';
import 'theme.dart';

class FreshLoopApp extends StatelessWidget {
  /// Inject a generator in tests; production builds one from real clients/keys.
  final RouteGenerator? generator;
  const FreshLoopApp({super.key, this.generator});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RouteGenCubit(generator ?? buildRouteGenerator()),
      child: MaterialApp.router(
        title: 'FreshLoop',
        theme: freshLoopTheme,
        routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
