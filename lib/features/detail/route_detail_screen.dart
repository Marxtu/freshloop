import 'package:flutter/material.dart';
import '../../data/photos/scene_photo.dart';
import '../../domain/models/scored_route.dart';
import '../../services/photo_service.dart';
import '../common/route_map.dart';
import '../common/tier_badge.dart';
import 'elevation_chart.dart';
import 'photo_carousel.dart';

/// The chosen route in full: the loop on a map, with a draggable sheet holding
/// the score breakdown, elevation profile, scenery photos, and actions.
class RouteDetailScreen extends StatefulWidget {
  final ScoredRoute route;
  final PhotoService photoService;

  /// Initial height of the detail sheet as a fraction of the screen.
  final double initialSheetSize;

  const RouteDetailScreen({
    super.key,
    required this.route,
    required this.photoService,
    this.initialSheetSize = 0.42,
  });

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  // Fetch photos once — the DraggableScrollableSheet builder rebuilds on every
  // scroll frame, so the future must NOT be created there (avoids repeated
  // network requests and spinner flashes).
  late final Future<List<ScenePhoto>> _photos =
      widget.photoService.photosForRoute(widget.route.geometry);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final route = widget.route;
    final s = route.score;
    final km = (route.geometry.distanceM / 1000).toStringAsFixed(1);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: RouteMap(points: route.geometry.points)),
          Positioned(
            top: 0, left: 0,
            child: SafeArea(child: BackButton(onPressed: () => Navigator.of(context).maybePop())),
          ),
          DraggableScrollableSheet(
            initialChildSize: widget.initialSheetSize,
            minChildSize: 0.2,
            maxChildSize: 0.9,
            builder: (context, controller) => Container(
              decoration: BoxDecoration(
                color: t.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Center(child: Container(width: 40, height: 4, color: t.colorScheme.outlineVariant)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(s.total.toStringAsFixed(0), style: t.textTheme.headlineLarge),
                      const SizedBox(width: 6),
                      Text('score', style: t.textTheme.bodySmall),
                      const Spacer(),
                      Text('$km km · ${route.geometry.ascentM.toStringAsFixed(0)} m up',
                          style: t.textTheme.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, children: [
                    TierBadge(axis: 'Air', tier: s.air.tier),
                    TierBadge(axis: 'Hills', tier: s.hills.tier),
                    TierBadge(axis: 'Scenery', tier: s.scenery.tier),
                  ]),
                  const SizedBox(height: 8),
                  Text(s.explanation, style: t.textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  Text('Elevation', style: t.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  ElevationChart(points: route.geometry.points),
                  const SizedBox(height: 16),
                  Text('Along the way', style: t.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  FutureBuilder<List<ScenePhoto>>(
                    future: _photos,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
                      }
                      return PhotoCarousel(photos: snap.data ?? const []);
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: null, // live tracking arrives in M4
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start run (M4)'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
