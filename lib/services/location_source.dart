import 'package:geolocator/geolocator.dart';
import '../data/routing/route_geometry.dart';

/// Source of live position updates. Abstracted so the tracking Cubit can be
/// unit-tested with a fake stream (no GPS, no plugin) — see design doc §7.
abstract class LocationSource {
  /// Ensures location permission is granted; returns true if usable.
  Future<bool> ensurePermission();

  /// A stream of the user's position as [RoutePoint]s.
  Stream<RoutePoint> positions();

  /// A single current fix (null if permission is denied / unavailable).
  Future<RoutePoint?> current();
}

/// Production implementation backed by the `geolocator` plugin.
class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource();

  @override
  Future<bool> ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Stream<RoutePoint> positions() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        ),
      ).map((p) => RoutePoint(lat: p.latitude, lng: p.longitude, elevation: p.altitude));

  @override
  Future<RoutePoint?> current() async {
    if (!await ensurePermission()) return null;
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return RoutePoint(lat: p.latitude, lng: p.longitude, elevation: p.altitude);
  }
}
