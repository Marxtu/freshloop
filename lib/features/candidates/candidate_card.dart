import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../domain/models/scored_route.dart';
import '../common/axis_stat.dart';
import '../common/route_map.dart';
import '../common/score_gauge.dart';

/// A tappable candidate: a map preview with the rank ribbon + key metrics over
/// a scrim, then the hero score gauge beside the per-axis stats and the
/// one-line explanation.
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
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RouteMap(points: route.geometry.points, interactive: false),
                  // bottom scrim so the white metric text stays legible over tiles
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 56,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0x8C000000), Color(0x00000000)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 10,
                    child: Row(
                      children: [
                        const Icon(Icons.straighten_rounded, size: 15, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('$km km · ${route.geometry.ascentM.toStringAsFixed(0)} m up',
                            style: t.textTheme.labelLarge
                                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Positioned(top: 10, left: 10, child: _rankRibbon(t)),
                  Positioned(top: 10, right: 10, child: _kindChip(t)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ScoreGauge(score: s.total, emphasize: rank == 1, size: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            AxisStat(axis: 'Air', tier: s.air.tier),
                            AxisStat(axis: 'Hills', tier: s.hills.tier),
                            AxisStat(axis: 'Scenery', tier: s.scenery.tier),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(s.explanation,
                            style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: t.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kindChip(ThemeData t) {
    final ob = route.kind == RouteKind.outAndBack;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 5, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ob ? Icons.swap_horiz_rounded : Icons.loop_rounded, size: 13, color: AppColors.ink),
          const SizedBox(width: 4),
          Text(ob ? 'Out & back' : 'Loop',
              style: t.textTheme.labelSmall?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _rankRibbon(ThemeData t) {
    final isBest = rank == 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isBest ? AppColors.accent : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isBest ? Icons.star_rounded : Icons.tag_rounded,
              size: 15, color: isBest ? Colors.white : AppColors.ink),
          const SizedBox(width: 3),
          Text(isBest ? 'Best match' : '$rank',
              style: t.textTheme.labelMedium
                  ?.copyWith(color: isBest ? Colors.white : AppColors.ink, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
