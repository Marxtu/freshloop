import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../app/app_config.dart';
import '../../data/geocoding/geo_place.dart';
import '../../data/geocoding/nominatim_client.dart';
import '../../data/routing/route_geometry.dart';
import '../../services/location_source.dart';
import '../../state/auth_cubit.dart';
import '../../state/route_gen_cubit.dart';
import '../../state/route_gen_state.dart';
import '../common/route_map.dart';
import '../params/params_sheet.dart';

/// Map-forward home: search a place or use GPS to choose the start, then design
/// the run from the bottom sheet.
class HomeScreen extends StatefulWidget {
  /// Injectable for tests; production uses the real geolocator-backed source.
  final LocationSource locationSource;

  /// Injectable for tests; defaults to the keyless Nominatim geocoder.
  final NominatimClient? geocoder;

  const HomeScreen({super.key, this.locationSource = const GeolocatorLocationSource(), this.geocoder});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final NominatimClient _geocoder =
      widget.geocoder ?? NominatimClient(userAgent: AppConfig.nominatimUserAgent);
  final _searchController = TextEditingController();

  // Milan Duomo as a sensible fallback until GPS or a search picks a start.
  double _lat = 45.4642;
  double _lng = 9.19;
  bool _locating = false;
  bool _searching = false;
  bool _located = false;

  @override
  void initState() {
    super.initState();
    _locate(); // best-effort auto-locate on open
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _locate({bool announce = false}) async {
    if (_locating) return;
    setState(() => _locating = true);
    RoutePoint? f;
    try {
      f = await widget.locationSource.current();
    } catch (_) {
      f = null;
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

  Future<void> _search(String raw) async {
    final q = raw.trim();
    if (q.isEmpty || _searching) return;
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    GeoPlace? place;
    try {
      place = await _geocoder.search(q);
    } catch (_) {
      place = null;
    }
    if (!mounted) return;
    final p = place;
    setState(() {
      if (p != null) {
        _lat = p.lat;
        _lng = p.lng;
        _located = true;
      }
      _searching = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(p != null ? 'Start: ${_short(p.label)}' : 'Couldn’t find “$q”'),
    ));
  }

  String _short(String label) {
    final parts = label.split(',');
    return parts.take(2).join(',').trim();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
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
                key: ValueKey('$_lat,$_lng'),
                points: const [],
                currentLocation: RoutePoint(lat: _lat, lng: _lng),
              ),
            ),
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      _searchBar(t),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
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
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
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
          ],
        ),
      ),
    );
  }

  Widget _searchBar(ThemeData t) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(30),
      shadowColor: Colors.black26,
      color: t.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.only(left: 14, right: 4),
        child: Row(
          children: [
            _searching
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.search, color: t.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: _search,
                decoration: const InputDecoration(
                  hintText: 'Search a place to start from…',
                  border: InputBorder.none,
                  filled: false,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            _locating
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    tooltip: _located ? 'Located — tap for current location' : 'Use my location',
                    onPressed: () => _locate(announce: true),
                    icon: Icon(_located ? Icons.my_location : Icons.location_searching,
                        color: t.colorScheme.primary),
                  ),
          ],
        ),
      ),
    );
  }
}
