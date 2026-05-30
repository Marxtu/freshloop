/// "mm:ss" under an hour, "h:mm:ss" at/over an hour.
String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Pace as `m'ss"` per km; `--'--"` when no meaningful distance.
String formatPace(double distanceM, int seconds) {
  if (distanceM < 1) return "--'--\"";
  final secPerKm = seconds / (distanceM / 1000);
  final m = secPerKm ~/ 60;
  final s = (secPerKm % 60).round();
  return "$m'${s.toString().padLeft(2, '0')}\"";
}
