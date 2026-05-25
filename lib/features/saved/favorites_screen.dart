import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../domain/models/scored_route.dart';
import '../../state/favorites_cubit.dart';
import '../common/axis_stat.dart';
import '../common/score_gauge.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final routes = context.watch<FavoritesCubit>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Favourite routes')),
      body: routes.isEmpty
          ? _empty(t)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: Insets.sm),
              itemCount: routes.length,
              itemBuilder: (context, i) {
                final ScoredRoute r = routes[i];
                final km = (r.geometry.distanceM / 1000).toStringAsFixed(1);
                return Card(
                  child: InkWell(
                    onTap: () => context.push('/detail', extra: r),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          ScoreGauge(score: r.score.total, size: 56),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.straighten_rounded, size: 15, color: t.colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Text('$km km · ${r.geometry.ascentM.toStringAsFixed(0)} m up',
                                        style: t.textTheme.titleSmall),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(spacing: 6, runSpacing: 6, children: [
                                  AxisStat(axis: 'Air', tier: r.score.air.tier),
                                  AxisStat(axis: 'Hills', tier: r.score.hills.tier),
                                  AxisStat(axis: 'Scenery', tier: r.score.scenery.tier),
                                ]),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: t.colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _empty(ThemeData t) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border_rounded, size: 40, color: t.colorScheme.onSurfaceVariant),
              const SizedBox(height: 10),
              Text('No favourites yet', style: t.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Tap the heart on a route to save it here.',
                  style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
