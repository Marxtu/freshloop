import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/scored_route.dart';
import '../../state/favorites_cubit.dart';
import '../common/tier_badge.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final routes = context.watch<FavoritesCubit>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Favourite routes')),
      body: routes.isEmpty
          ? const Center(child: Text('No favourites yet — tap the heart on a route.'))
          : ListView.builder(
              itemCount: routes.length,
              itemBuilder: (context, i) {
                final ScoredRoute r = routes[i];
                return ListTile(
                  isThreeLine: true,
                  title: Text('${r.score.total.toStringAsFixed(0)} · ${(r.geometry.distanceM / 1000).toStringAsFixed(1)} km'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.score.explanation),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, children: [
                        TierBadge(axis: 'Air', tier: r.score.air.tier),
                        TierBadge(axis: 'Hills', tier: r.score.hills.tier),
                        TierBadge(axis: 'Scenery', tier: r.score.scenery.tier),
                      ]),
                    ],
                  ),
                  onTap: () => context.push('/detail', extra: r),
                );
              },
            ),
    );
  }
}
