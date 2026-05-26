import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../data/routing/route_geometry.dart';
import '../../services/location_source.dart';
import '../../state/auth_cubit.dart';
import '../../state/route_gen_cubit.dart';
import '../../state/route_gen_state.dart';
import '../common/route_map.dart';
import '../params/params_sheet.dart';

/// Map-forward home: the map fills the screen; a bottom sheet holds the params.
/// Tries to locate the user on open, and offers a "locate me" button so the
/// run is designed from the runner's real position (falling back to Milan).
class HomeScreen extends StatefulWidget {
  /// Injectable for tests; production uses the real geolocator-backed source.
  final LocationSource locationSource;
  const HomeScreen({super.key, this.locationSource = const GeolocatorLocationSource()});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Milan Duomo as a sensible fallback until a GPS fix arrives.
  double _lat = 45.4642;
  double _lng = 9.19;
  bool _locating = false;
  bool _located = false;

  @override
  void initState() {
    super.initState();
    _locate(); // best-effort auto-locate on open
  }

  Future<void> _locate({bool announce = false}) async {
    if (_locating) return;
    setState(() => _locating = true);
    RoutePoint? f;
    try {
      f = await widget.locationSource.current();
    } catch (_) {
      f = null; // no plugin / denied / timeout — keep the fallback
    }
    if (!mounted) return;
    final fix = f;
    setState(() {
      if (fix != null) {
        _lat = fix.lat;
        _lng = fix.lng;
        _located = true;
      }
      _locating = false;
    });
    if (announce && fix == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location unavailable — using Milan centre. Check location permission.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit?>();
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
            Positioned.fill(
              child: RouteMap(
                // Re-centre when the located start changes.
                key: ValueKey('$_lat,$_lng'),
                points: const [],
                currentLocation: RoutePoint(lat: _lat, lng: _lng),
              ),
            ),
            // Locate-me control (top-left, balances the nav icons on the right).
            Positioned(
              top: 0, left: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton.filledTonal(
                    tooltip: _located ? 'Located — tap to refresh' : 'Use my location',
                    onPressed: _locating ? null : () => _locate(announce: true),
                    icon: _locating
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(_located ? Icons.my_location : Icons.location_searching),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                // Full-width on phones; a centred panel on wide (tablet / web) screens.
                constraints: const BoxConstraints(maxWidth: 480),
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
                              startLat: _lat,
                              startLng: _lng,
                              onGenerate: (p) => context.read<RouteGenCubit>().generate(p),
                            ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.history),
                      tooltip: 'Run history',
                      onPressed: () => context.push('/history'),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.favorite),
                      tooltip: 'Favourite routes',
                      onPressed: () => context.push('/favorites'),
                    ),
                    if (authCubit != null) ...[
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.logout),
                        tooltip: 'Sign out',
                        onPressed: () => authCubit.signOut(),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
