import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../app/dependencies.dart';
import '../../domain/format.dart';
import '../../domain/models/run_record.dart';
import '../../domain/models/scored_route.dart';
import '../../services/run_history_repository.dart';
import '../common/route_map.dart';
import '../common/stat_trio.dart';

/// Post-run summary: the actual trail, headline stats, and (if the run followed
/// a planned route) planned-vs-actual distance. Save persists the run to the
/// local history repository.
class RunSummaryScreen extends StatefulWidget {
  final RunRecord record;
  final ScoredRoute? planned;
  final RunHistoryRepository? historyRepo; // inject in tests; defaults to the app repo
  const RunSummaryScreen({super.key, required this.record, this.planned, this.historyRepo});

  @override
  State<RunSummaryScreen> createState() => _RunSummaryScreenState();
}

class _RunSummaryScreenState extends State<RunSummaryScreen> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final km = (widget.record.distanceM / 1000).toStringAsFixed(2);
    return Scaffold(
      appBar: AppBar(title: const Text('Run summary')),
      body: ListView(
        children: [
          SizedBox(height: 220, child: RouteMap(points: widget.record.points, interactive: false)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: t.colorScheme.primary, size: 26),
                    const SizedBox(width: 8),
                    Text('Run complete', style: t.textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    child: StatTrio([
                      (km, 'km'),
                      (formatDuration(widget.record.durationS), 'time'),
                      (formatPace(widget.record.distanceM, widget.record.durationS), 'pace'),
                    ]),
                  ),
                ),
                if (widget.planned != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.route_rounded, size: 16, color: t.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Planned ${(widget.planned!.geometry.distanceM / 1000).toStringAsFixed(1)} km · ran $km km',
                            style: t.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saved
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                await (widget.historyRepo ?? buildHistoryRepository()).save(widget.record);
                                if (!mounted) return;
                                setState(() => _saved = true);
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Saved to history')),
                                );
                              },
                        icon: Icon(_saved ? Icons.bookmark_added : Icons.bookmark_border),
                        label: Text(_saved ? 'Saved' : 'Save'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(text: 'I ran $km km in ${formatDuration(widget.record.durationS)} with FreshLoop!'),
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
}
