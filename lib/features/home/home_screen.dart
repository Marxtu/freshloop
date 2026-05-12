import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../state/route_gen_cubit.dart';
import '../../state/route_gen_state.dart';
import '../common/route_map.dart';
import '../params/params_sheet.dart';

/// Map-forward home: the map fills the screen; a bottom sheet holds the params.
/// On a successful generation it navigates to the candidates screen.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Milan Duomo as a sensible default start until live location is wired (M4).
  static const _startLat = 45.4642;
  static const _startLng = 9.19;

  @override
  Widget build(BuildContext context) {
    return BlocListener<RouteGenCubit, RouteGenState>(
      listener: (context, state) {
        if (state is RouteGenLoaded) {
          context.go('/candidates');
        } else if (state is RouteGenError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not generate a route: ${state.message}')),
          );
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: RouteMap(points: [])),
            Align(
              alignment: Alignment.bottomCenter,
              child: BlocBuilder<RouteGenCubit, RouteGenState>(
                builder: (context, state) {
                  final loading = state is RouteGenLoading;
                  return Card(
                    margin: const EdgeInsets.all(12),
                    child: loading
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : ParamsSheet(
                            startLat: _startLat,
                            startLng: _startLng,
                            onGenerate: (p) => context.read<RouteGenCubit>().generate(p),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
