import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../state/route_gen_cubit.dart';
import '../../state/route_gen_state.dart';
import 'candidate_card.dart';

/// Shows the ranked candidates from the Cubit's loaded state.
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
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: routes.length,
              itemBuilder: (context, i) => CandidateCard(
                route: routes[i],
                rank: i + 1,
                onTap: () {}, // route detail = M3.3
              ),
            ),
    );
  }
}
