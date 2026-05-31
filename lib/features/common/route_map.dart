import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/routing/route_geometry.dart';

/// A map showing a route polyline (and optionally a start marker) over OSM
/// tiles. [interactive] is false for small card previews.
/// [currentLocation] when non-null shows a distinct blue dot at that position.
class RouteMap extends StatelessWidget {
  final List<RoutePoint> points;
  final bool interactive;
  final RoutePoint? currentLocation;

  /// Called with the map centre whenever the camera moves (used to bias search
  /// to what the user is looking at — "search this area"). Null on previews.
  final void Function(LatLng center)? onCenterChanged;

  /// Called when the user long-presses the map (used to drop a start point).
  final void Function(LatLng point)? onLongPress;

  const RouteMap({
    super.key,
    required this.points,
    this.interactive = true,
    this.currentLocation,
    this.onCenterChanged,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final latLngs = points.map((p) => LatLng(p.lat, p.lng)).toList();
    final center = latLngs.isNotEmpty
        ? latLngs.first
        : (currentLocation != null
            ? LatLng(currentLocation!.lat, currentLocation!.lng)
            : const LatLng(45.4642, 9.19));
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
        onLongPress: onLongPress == null ? null : (_, point) => onLongPress!(point),
        onPositionChanged:
            onCenterChanged == null ? null : (camera, _) => onCenterChanged!(camera.center),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'it.polimi.freshloop',
        ),
        if (latLngs.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(points: latLngs, strokeWidth: 5, color: Theme.of(context).colorScheme.primary),
            ],
          ),
        if (latLngs.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: latLngs.first,
                child: Icon(Icons.place, color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        if (currentLocation != null)
          MarkerLayer(markers: [
            Marker(
              point: LatLng(currentLocation!.lat, currentLocation!.lng),
              width: 22,
              height: 22,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
          ]),
      ],
    );
  }
}
