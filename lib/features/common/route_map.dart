import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/routing/route_geometry.dart';

/// A map showing a route polyline (and optionally a start marker) over OSM
/// tiles. [interactive] is false for small card previews.
class RouteMap extends StatelessWidget {
  final List<RoutePoint> points;
  final bool interactive;
  const RouteMap({super.key, required this.points, this.interactive = true});

  @override
  Widget build(BuildContext context) {
    final latLngs = points.map((p) => LatLng(p.lat, p.lng)).toList();
    final center = latLngs.isEmpty ? const LatLng(45.4642, 9.19) : latLngs.first;
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
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
      ],
    );
  }
}
