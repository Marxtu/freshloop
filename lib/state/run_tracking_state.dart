import '../domain/models/run_record.dart';
import '../data/routing/route_geometry.dart';

/// States for live run tracking (design doc §7).
sealed class RunTrackingState {
  const RunTrackingState();
}

class RunIdle extends RunTrackingState {
  const RunIdle();
}

class RunPermissionDenied extends RunTrackingState {
  const RunPermissionDenied();
}

class RunInProgress extends RunTrackingState {
  final double distanceM;
  final List<RoutePoint> points;
  const RunInProgress({required this.distanceM, required this.points});
}

class RunFinished extends RunTrackingState {
  final RunRecord record;
  const RunFinished(this.record);
}
