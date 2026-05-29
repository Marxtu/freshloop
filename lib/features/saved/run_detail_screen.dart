import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/format.dart';
import '../../domain/models/run_record.dart';
import '../common/route_map.dart';
import '../common/stat_trio.dart';

/// A past run opened from the history list: its GPS trail on a map, the headline
/// stats, and when it happened. Read-only (the run is already saved) — distinct
/// from [RunSummaryScreen], which is the just-finished flow with Save/Done.
class RunDetailScreen extends StatelessWidget {
  final RunRecord record;
  const RunDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final km = (record.distanceM / 1000).toStringAsFixed(2);
    final hasTrail = record.points.length > 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Run details'),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share),
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text: 'I ran $km km in ${formatDuration(record.durationS)} with FreshLoop!',
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 260,
            child: hasTrail
                ? RouteMap(points: record.points, interactive: true)
                : Container(
                    color: t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 36, color: t.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text('No GPS trail recorded for this run',
                            style: t.textTheme.bodyMedium
                                ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (record.startedAt != null) ...[
                  Row(
                    children: [
                      Icon(Icons.event_rounded, size: 18, color: t.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(formatRunDate(record.startedAt!),
                          style: t.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    child: StatTrio([
                      (km, 'km'),
                      (formatDuration(record.durationS), 'time'),
                      (formatPace(record.distanceM, record.durationS), 'pace'),
                    ]),
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
