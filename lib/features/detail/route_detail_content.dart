import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/photos/scene_photo.dart';
import '../../domain/models/scored_route.dart';
import '../common/tier_badge.dart';
import 'elevation_chart.dart';
import 'photo_carousel.dart';

/// The scrollable body of the route detail: the score + tier badges, the
/// one-line explanation, the elevation profile, the "Along the way" scenery
/// photos, and the "Start run" action. Shared by both layouts (the narrow
/// draggable sheet and the wide side-by-side panel) so there is a single
/// source of truth.
///
/// [photos] is the photos future created once in the parent State — it must NOT
/// be recreated here, since this widget can rebuild on every scroll frame.
/// [controller] is the enclosing scroll controller (the sheet's draggable
/// controller on narrow, the panel's own controller on wide). [leading] lets
/// the narrow sheet prepend its drag handle inside the same scroll view.
class RouteDetailContent extends StatelessWidget {
  final ScoredRoute route;
  final Future<List<ScenePhoto>> photos;
  final ScrollController? controller;
  final Widget? leading;
  final VoidCallback onStartRun;

  const RouteDetailContent({
    super.key,
    required this.route,
    required this.photos,
    required this.onStartRun,
    this.controller,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = route.score;
    final km = (route.geometry.distanceM / 1000).toStringAsFixed(1);
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        ?leading,
        Row(
          children: [
            Text(s.total.toStringAsFixed(0),
                style: t.textTheme.headlineLarge?.copyWith(color: AppColors.seed)),
            const SizedBox(width: 6),
            Text('score', style: t.textTheme.bodySmall),
            const Spacer(),
            Flexible(
              child: Text(
                '$km km · ${route.geometry.ascentM.toStringAsFixed(0)} m up',
                style: t.textTheme.bodyMedium,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
          future: photos,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
            }
            return PhotoCarousel(photos: snap.data ?? const []);
          },
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onStartRun,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start run'),
        ),
      ],
    );
  }
}
