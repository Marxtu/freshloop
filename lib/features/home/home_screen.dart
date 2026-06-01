import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../app/app_config.dart';
import '../../data/geocoding/geo_place.dart';
import '../../data/geocoding/photon_client.dart';
import '../../data/routing/route_geometry.dart';
import '../../domain/format.dart';
import '../../domain/geo.dart';
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

  /// Injectable for tests; defaults to the keyless Photon (type-ahead) geocoder.
  final PhotonClient? geocoder;

  const HomeScreen({super.key, this.locationSource = const GeolocatorLocationSource(), this.geocoder});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PhotonClient _geocoder =
      widget.geocoder ?? PhotonClient(userAgent: AppConfig.geocoderUserAgent);
  final _searchController = TextEditingController();

  // Milan Duomo as a sensible fallback until GPS or a search picks a start.
  double _lat = 45.4642;
  double _lng = 9.19;
  // The device's actual GPS fix (null until located) — the origin for the
  // "distance from you" hints in the suggestion list.
  double? _myLat;
  double? _myLng;
  // The map's current centre, tracked as the user pans, so search biases to
  // what they're looking at ("search this area"). Null until the map reports.
  double? _mapLat;
  double? _mapLng;
  bool _locating = false;
  bool _searching = false;
  bool _located = false;
  List<GeoPlace> _suggestions = const [];
  bool _noMatches = false; // a search ran and returned nothing (show a hint)
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _locate(); // best-effort auto-locate on open
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Debounced autocomplete: fetch nearby-first place suggestions as the user
  /// types (skip very short queries; one request ~400 ms after they stop).
  void _onQueryChanged(String raw) {
    final q = raw.trim();
    _debounce?.cancel();
    if (q.length < 2) {
      if (_suggestions.isNotEmpty || _noMatches) {
        setState(() {
          _suggestions = const [];
          _noMatches = false;
        });
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final lat = _mapLat ?? _lat, lng = _mapLng ?? _lng; // bias to what's on screen
      List<GeoPlace> r;
      try {
        r = await _geocoder.suggest(q, lat: lat, lng: lng);
      } catch (_) {
        r = const [];
      }
      if (mounted) {
        setState(() {
          _suggestions = _byDistance(r);
          _noMatches = r.isEmpty;
        });
      }
    });
  }

  void _selectPlace(GeoPlace p) {
    _debounce?.cancel();
    FocusScope.of(context).unfocus();
    _searchController.text = _short(p.label);
    setState(() {
      _lat = p.lat;
      _lng = p.lng;
      _located = true;
      _suggestions = const [];
      _noMatches = false;
    });
  }

  // Track the map centre as the user pans (no rebuild — just remembered for the
  // next search, so results follow "this area").
  void _onMapMoved(LatLng c) {
    _mapLat = c.latitude;
    _mapLng = c.longitude;
  }

  /// Long-press anywhere on the map to start a run from there. Sets the point
  /// immediately and reverse-geocodes a label in the background (best effort).
  Future<void> _setStartFromMap(LatLng p) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _lat = p.latitude;
      _lng = p.longitude;
      _located = true;
      _suggestions = const [];
      _noMatches = false;
    });
    GeoPlace? place;
    try {
      place = await _geocoder.reverse(p.latitude, p.longitude);
    } catch (_) {
      place = null;
    }
    if (!mounted) return;
    final label = place?.label;
    if (label != null && label.isNotEmpty) _searchController.text = _short(label);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(label != null && label.isNotEmpty ? 'Start: ${_short(label)}' : 'Start set on the map'),
    ));
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
        _myLat = fix.lat;
        _myLng = fix.lng;
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
      // Bias to what's on screen (same as the dropdown), so submitting
      // "Carrefour" picks one near the user, not a global match.
      final lat = _mapLat ?? _lat, lng = _mapLng ?? _lng;
      final r = await _geocoder.suggest(q, lat: lat, lng: lng, limit: 1);
      place = r.isEmpty ? null : r.first;
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
          // push (not go) so candidates stacks on top of home — otherwise the
          // Android back button on candidates/detail/… has nothing to pop and
          // exits the app instead of returning to the previous screen.
          context.push('/candidates');
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
                onCenterChanged: _onMapMoved,
                onLongPress: _setStartFromMap,
              ),
            ),
            _sheet(context),
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      _searchBar(t),
                      const SizedBox(height: 8),
                      if (_suggestions.isNotEmpty)
                        _suggestionsCard(t)
                      else if (_noMatches)
                        _noMatchesCard(t)
                      else
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
          ],
        ),
      ),
    );
  }

  /// The collapsible "Design your run" sheet. Drag down to a handle to free the
  /// map (and see the start dot); drag up to set params.
  Widget _sheet(BuildContext context) {
    final t = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.46,
      minChildSize: 0.12,
      maxChildSize: 0.88,
      snap: true,
      snapSizes: const [0.12, 0.46, 0.88],
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: t.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: BlocBuilder<RouteGenCubit, RouteGenState>(
          builder: (context, state) {
            final loading = state is RouteGenLoading;
            return ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 2),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                if (loading)
                  const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                else
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: ParamsSheet(
                        startLat: _lat,
                        startLng: _lng,
                        onGenerate: (p) => context.read<RouteGenCubit>().generate(p),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _suggestionsCard(ThemeData t) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black26,
      color: t.colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: _suggestions.length,
          separatorBuilder: (_, _) => Divider(height: 1, color: t.colorScheme.outlineVariant),
          itemBuilder: (context, i) {
            final p = _suggestions[i];
            return ListTile(
              dense: true,
              leading: Icon(Icons.place_outlined, color: t.colorScheme.primary),
              title: Text(_short(p.label), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(p.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              trailing: _distanceLabel(t, p),
              onTap: () => _selectPlace(p),
            );
          },
        ),
      ),
    );
  }

  /// Orders suggestions nearest-first by straight-line distance from the user's
  /// GPS fix, so the closest "Carrefour" is at the top (matching the distance
  /// labels). Left in the geocoder's order when we have no fix to measure from.
  List<GeoPlace> _byDistance(List<GeoPlace> places) {
    final oLat = _myLat, oLng = _myLng;
    if (oLat == null || oLng == null) return places;
    final origin = RoutePoint(lat: oLat, lng: oLng);
    double dist(GeoPlace p) => haversineMeters(origin, RoutePoint(lat: p.lat, lng: p.lng));
    return [...places]..sort((a, b) => dist(a).compareTo(dist(b)));
  }

  /// A compact straight-line distance from the device's GPS fix to [p], shown
  /// at the trailing edge of a suggestion. Returns null when we have no real
  /// fix yet, so we never show a misleading distance from the fallback centre.
  Widget? _distanceLabel(ThemeData t, GeoPlace p) {
    final oLat = _myLat, oLng = _myLng;
    if (oLat == null || oLng == null) return null;
    final meters = haversineMeters(
      RoutePoint(lat: oLat, lng: oLng),
      RoutePoint(lat: p.lat, lng: p.lng),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.near_me_outlined, size: 14, color: t.colorScheme.primary),
        const SizedBox(height: 2),
        Text(formatDistance(meters),
            style: t.textTheme.labelSmall?.copyWith(
                color: t.colorScheme.primary, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _noMatchesCard(ThemeData t) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black26,
      color: t.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.search_off_rounded, color: t.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text('No matches — check the spelling, or pan the map and search again.',
                  style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
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
                onChanged: _onQueryChanged,
                onSubmitted: (q) =>
                    _suggestions.isNotEmpty ? _selectPlace(_suggestions.first) : _search(q),
                decoration: const InputDecoration(
                  hintText: 'Search a place to start from…',
                  border: InputBorder.none,
                  filled: false,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (_, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear',
                      onPressed: () {
                        _debounce?.cancel();
                        _searchController.clear();
                        setState(() {
                          _suggestions = const [];
                          _noMatches = false;
                        });
                      },
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
