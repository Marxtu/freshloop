import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/format.dart';
import '../../domain/models/run_record.dart';
import '../../domain/models/scored_route.dart';
import '../common/route_map.dart';

/// Post-run summary: the actual trail, headline stats, and (if the run followed
/// a planned route) planned-vs-actual distance. Save is a placeholder (M5).
class RunSummaryScreen extends StatelessWidget {
  final RunRecord record;
  final ScoredRoute? planned;
  const RunSummaryScreen({super.key, required this.record, this.planned});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final km = (record.distanceM / 1000).toStringAsFixed(2);
    return Scaffold(
      appBar: AppBar(title: const Text('Run summary')),
      body: ListView(
        children: [
          SizedBox(height: 220, child: RouteMap(points: record.points, interactive: false)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat(t, km, 'km'),
                    _stat(t, formatDuration(record.durationS), 'time'),
                    _stat(t, formatPace(record.distanceM, record.durationS), 'pace'),
                  ],
                ),
                if (planned != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Planned ${(planned!.geometry.distanceM / 1000).toStringAsFixed(1)} km · '
                    'ran $km km',
                    style: t.textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: null, // saving to history arrives in M5
                        icon: const Icon(Icons.bookmark_border),
                        label: const Text('Save (M5)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(text: 'I ran $km km in ${formatDuration(record.durationS)} with FreshLoop!'),
                        ),
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(ThemeData t, String value, String label) => Column(
        children: [
          Text(value, style: t.textTheme.headlineSmall),
          Text(label, style: t.textTheme.bodySmall),
        ],
      );
}
