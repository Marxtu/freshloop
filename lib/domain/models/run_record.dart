import '../../data/routing/route_geometry.dart';

/// A completed (or in-progress snapshot of a) run: the GPS trail, total
/// distance, and elapsed time. See design doc §8.
class RunRecord {
  final List<RoutePoint> points;
  final double distanceM;
  final int durationS;

  /// When the run started. Null for records saved before this field existed
  /// (older history entries) — the UI degrades gracefully when it's missing.
  final DateTime? startedAt;

  const RunRecord({
    required this.points,
    required this.distanceM,
    required this.durationS,
    this.startedAt,
  });

  /// Average pace in seconds per kilometre (0 when no distance was covered).
  double get paceSecPerKm => distanceM <= 0 ? 0 : durationS / (distanceM / 1000);

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => p.toJson()).toList(),
        'distanceM': distanceM,
        'durationS': durationS,
        if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
      };
  factory RunRecord.fromJson(Map<String, dynamic> j) => RunRecord(
        points: (j['points'] as List).map((e) => RoutePoint.fromJson(e as Map<String, dynamic>)).toList(),
        distanceM: (j['distanceM'] as num).toDouble(),
        durationS: (j['durationS'] as num).toInt(),
        startedAt: j['startedAt'] == null ? null : DateTime.parse(j['startedAt'] as String),
      );
}
