import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../app/responsive.dart';
import '../../domain/models/scored_route.dart';
import '../../state/route_gen_cubit.dart';
import '../../state/route_gen_state.dart';
import 'candidate_card.dart';

/// Shows the ranked candidates from the Cubit's loaded state. On phone-portrait
/// widths the cards stack in a single list; on wide (tablet/landscape) screens
/// they flow into a multi-column grid so the ranking stays scannable.
class CandidatesScreen extends StatelessWidget {
  const CandidatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RouteGenCubit>().state;
    final routes = state is RouteGenLoaded ? state.routes : const [];
    final target = state is RouteGenLoaded ? state.targetDistanceM : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your route')),
      body: routes.isEmpty
          ? const Center(child: Text('No routes — try generating again.'))
          : Column(
              children: [
                _distanceMismatchBanner(context, routes, target),
                Expanded(child: _list(context, routes)),
              ],
            ),
    );
  }

  /// A note shown when no loop near the requested distance was possible (sparse
  /// trail network), explaining the out-and-back + shortest-loop fallback.
  Widget _distanceMismatchBanner(BuildContext context, List<dynamic> routes, double? target) {
    if (target == null || target <= 0 || routes.isEmpty) return const SizedBox.shrink();
    final loops = routes.where((r) => r.kind == RouteKind.loop).toList();
    if (loops.isEmpty) return const SizedBox.shrink();
    final loopDists = loops.map((r) => (r.geometry.distanceM as double)).toList();
    final closestLoop = loopDists.reduce((a, b) => (a - target).abs() < (b - target).abs() ? a : b);
    if ((closestLoop - target).abs() / target <= 0.5) return const SizedBox.shrink(); // a loop fits
    final shortestLoop = loopDists.reduce((a, b) => a < b ? a : b);
    final hasBack = routes.any((r) => r.kind == RouteKind.outAndBack);
    final t = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF6),
        border: Border.all(color: const Color(0x59F59E0B)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No ~${(target / 1000).toStringAsFixed(1)} km loop near this start — the trail network here is sparse. '
              '${hasBack ? "Showing an out-and-back near your distance, plus " : "Showing "}'
              'the shortest loop (~${(shortestLoop / 1000).toStringAsFixed(1)} km). Try a denser start or a longer distance.',
              style: t.textTheme.bodySmall?.copyWith(color: const Color(0xFF7A5B12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, List<dynamic> routes) {
    return isWide(context)
              ? GridView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 480,
                    mainAxisExtent: 460, // headroom for a wrapped badge row + 2-line explanation
                  ),
                  itemCount: routes.length,
                  itemBuilder: (context, i) => CandidateCard(
                    route: routes[i],
                    rank: i + 1,
                    onTap: () => context.push('/detail', extra: routes[i]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: routes.length,
                  itemBuilder: (context, i) => CandidateCard(
                    route: routes[i],
                    rank: i + 1,
                    onTap: () => context.push('/detail', extra: routes[i]),
                  ),
                );
  }
}
