import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../domain/models/scored_route.dart';
import '../common/route_map.dart';
import '../common/tier_badge.dart';

/// A tappable candidate: a small non-interactive map preview, the total score
/// (amber for the #1 rank), the per-axis badges, and the one-line explanation.
class CandidateCard extends StatelessWidget {
  final ScoredRoute route;
  final int rank; // 1 = best
  final VoidCallback onTap;
  const CandidateCard({super.key, required this.route, required this.rank, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = route.score;
    final km = (route.geometry.distanceM / 1000).toStringAsFixed(1);
    final totalColor = rank == 1 ? AppColors.accent : t.colorScheme.onSurface;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 140,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RouteMap(points: route.geometry.points, interactive: false),
                  ),
                  Positioned(top: 10, left: 10, child: _rankBadge(t)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(s.total.toStringAsFixed(0),
                          style: t.textTheme.headlineMedium?.copyWith(color: totalColor)),
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
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      TierBadge(axis: 'Air', tier: s.air.tier),
                      TierBadge(axis: 'Hills', tier: s.hills.tier),
                      TierBadge(axis: 'Scenery', tier: s.scenery.tier),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(s.explanation,
                            style: t.textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, color: t.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A pill over the map preview making the rank explicit (the screen ranks
  /// candidates, so #1 gets the amber "Best match" treatment).
  Widget _rankBadge(ThemeData t) {
    final isBest = rank == 1;
    final bg = isBest ? AppColors.accent : t.colorScheme.surface;
    final fg = isBest ? Colors.white : t.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isBest ? Icons.star_rounded : Icons.tag, size: 15, color: fg),
          const SizedBox(width: 3),
          Text(
            isBest ? 'Best match' : '$rank',
            style: t.textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
