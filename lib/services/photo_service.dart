import '../data/photos/mapillary_client.dart';
import '../data/photos/scene_photo.dart';
import '../data/photos/wikimedia_client.dart';
import '../data/routing/route_geometry.dart';
import '../domain/geo.dart';

/// Collects along-route scenery photos from Mapillary + Wikimedia over a few
/// sampled waypoints. Each source/waypoint failure is swallowed (photos are
/// decorative — design §11), and results are de-duplicated by url.
class PhotoService {
  final MapillaryPhotoClient mapillary;
  final WikimediaPhotoClient wikimedia;

  PhotoService({required this.mapillary, required this.wikimedia});

  Future<List<ScenePhoto>> photosForRoute(
    RouteGeometry geometry, {
    int maxWaypoints = 3,
    int perSource = 2,
  }) async {
    const d = 0.0015; // ~150 m bbox half-size for Mapillary (small = avoids 500s)
    final waypoints = subsample(geometry.points, maxWaypoints);

    // Fetch every source/waypoint concurrently — a sequential loop made the
    // "Along the way" strip slow to appear. Each failure degrades to [].
    Future<List<ScenePhoto>> safe(Future<List<ScenePhoto>> Function() f) async {
      try {
        return await f();
      } catch (_) {
        return const [];
      }
    }

    final futures = <Future<List<ScenePhoto>>>[];
    for (final wp in waypoints) {
      futures.add(safe(() => mapillary.photosInBbox(
            south: wp.lat - d, west: wp.lng - d, north: wp.lat + d, east: wp.lng + d,
            limit: perSource,
          )));
      futures.add(safe(() => wikimedia.photosNear(
            lat: wp.lat, lng: wp.lng, radiusM: 250, limit: perSource,
          )));
    }
    final photos = (await Future.wait(futures)).expand((x) => x).toList();

    final seen = <String>{};
    return photos.where((p) => seen.add(p.url)).toList();
  }
}
