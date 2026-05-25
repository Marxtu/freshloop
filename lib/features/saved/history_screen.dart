import 'package:flutter/material.dart';
import '../../domain/format.dart';
import '../../domain/models/run_record.dart';
import '../../services/run_history_repository.dart';

class HistoryScreen extends StatelessWidget {
  final RunHistoryRepository repo;
  const HistoryScreen({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_run_rounded, size: 40, color: t.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 10),
                    Text('No runs yet', style: t.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('Finish a run to see it here.',
                        style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: runs.length,
            itemBuilder: (context, i) {
              final r = runs[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: t.colorScheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.directions_run_rounded, color: t.colorScheme.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${(r.distanceM / 1000).toStringAsFixed(2)} km',
                                style: t.textTheme.titleLarge),
                            const SizedBox(height: 2),
                            Text('${formatDuration(r.durationS)} · ${formatPace(r.distanceM, r.durationS)} /km',
                                style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
