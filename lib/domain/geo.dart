import 'dart:math' as math;

import '../data/routing/route_geometry.dart';

/// A geographic bounding box (used for area queries like Overpass).
class BoundingBox {
  final double south;
  final double west;
  final double north;
  final double east;

  const BoundingBox({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });
}

/// The bounding box of [points], expanded outward by [padDeg] degrees.
/// Throws [ArgumentError] if [points] is empty.
BoundingBox boundingBoxOf(List<RoutePoint> points, {double padDeg = 0.002}) {
  if (points.isEmpty) {
    throw ArgumentError('points must not be empty');
  }
  var south = points.first.lat, north = points.first.lat;
  var west = points.first.lng, east = points.first.lng;
  for (final p in points) {
    if (p.lat < south) south = p.lat;
    if (p.lat > north) north = p.lat;
    if (p.lng < west) west = p.lng;
    if (p.lng > east) east = p.lng;
  }
  return BoundingBox(
    south: south - padDeg,
    west: west - padDeg,
    north: north + padDeg,
    east: east + padDeg,
  );
}

/// Evenly downsamples [points] to at most [max] items, always keeping the
/// first and last. Returns the input unchanged when it already fits.
List<RoutePoint> subsample(List<RoutePoint> points, int max) {
  if (max <= 0) return const [];
  if (points.length <= max) return points;
  if (max == 1) return [points.first];
  final step = (points.length - 1) / (max - 1);
  final out = <RoutePoint>[];
  for (var i = 0; i < max; i++) {
    out.add(points[(i * step).round()]);
  }
  return out;
}

/// Great-circle distance between two points, in metres (Haversine).
double haversineMeters(RoutePoint a, RoutePoint b) {
  const earthRadiusM = 6371000.0;
  double rad(double deg) => deg * math.pi / 180.0;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final lat1 = rad(a.lat);
  final lat2 = rad(b.lat);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return earthRadiusM * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}
