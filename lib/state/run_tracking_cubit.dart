import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/routing/route_geometry.dart';
import '../domain/geo.dart';
import '../domain/models/run_record.dart';
import '../services/location_source.dart';
import 'run_tracking_state.dart';

/// Drives a live run: subscribes to the [LocationSource], accumulates distance
/// via haversine, and finishes with a [RunRecord]. Cancels its subscription in
/// [close] (GPS lifecycle discipline, design doc §7).
class RunTrackingCubit extends Cubit<RunTrackingState> {
  final LocationSource source;
  StreamSubscription<RoutePoint>? _sub;
  final List<RoutePoint> _points = [];
  final Stopwatch _watch = Stopwatch();
  double _distanceM = 0;
  DateTime? _startedAt;

  RunTrackingCubit(this.source) : super(const RunIdle());

  Future<void> start() async {
    if (!await source.ensurePermission()) {
      emit(const RunPermissionDenied());
      return;
    }
    _points.clear();
    _distanceM = 0;
    _startedAt = DateTime.now();
    _watch
      ..reset()
      ..start();
    emit(const RunInProgress(distanceM: 0, points: []));
    _sub = source.positions().listen((p) {
      if (_points.isNotEmpty) {
        _distanceM += haversineMeters(_points.last, p);
      }
      _points.add(p);
      emit(RunInProgress(distanceM: _distanceM, points: List.unmodifiable(_points)));
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _watch.stop();
    emit(RunFinished(RunRecord(
      points: List.of(_points),
      distanceM: _distanceM,
      durationS: _watch.elapsed.inSeconds,
      startedAt: _startedAt,
    )));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
