import 'package:flutter/material.dart';
import '../../domain/format.dart';
import '../../domain/models/run_record.dart';
import '../../services/run_history_repository.dart';

class HistoryScreen extends StatelessWidget {
  final RunHistoryRepository repo;
  const HistoryScreen({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Run history')),
      body: FutureBuilder<List<RunRecord>>(
        future: repo.all(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final runs = snap.data ?? const [];
          if (runs.isEmpty) {
            return const Center(child: Text('No runs yet — finish a run to see it here.'));
          }
          return ListView.separated(
            itemCount: runs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = runs[i];
              return ListTile(
                leading: const Icon(Icons.directions_run),
                title: Text('${(r.distanceM / 1000).toStringAsFixed(2)} km'),
                subtitle: Text('${formatDuration(r.durationS)} · ${formatPace(r.distanceM, r.durationS)} /km'),
              );
            },
          );
        },
      ),
    );
  }
}
