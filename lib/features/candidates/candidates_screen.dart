import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../app/responsive.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your route')),
      body: routes.isEmpty
          ? const Center(child: Text('No routes — try generating again.'))
          : isWide(context)
              ? GridView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 480,
                    mainAxisExtent: 400,
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
                ),
    );
  }
}
