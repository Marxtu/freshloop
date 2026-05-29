/// "mm:ss" under an hour, "h:mm:ss" at/over an hour.
String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// A short, locale-neutral run date like "28 May 2026, 14:32".
String formatRunDate(DateTime when) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${when.day} ${_months[when.month - 1]} ${when.year}, '
      '${two(when.hour)}:${two(when.minute)}';
}

/// Pace as `m'ss"` per km; `--'--"` when no meaningful distance.
String formatPace(double distanceM, int seconds) {
  if (distanceM < 1) return "--'--\"";
  final secPerKm = seconds / (distanceM / 1000);
  final m = secPerKm ~/ 60;
  final s = (secPerKm % 60).round();
  return "$m'${s.toString().padLeft(2, '0')}\"";
}
