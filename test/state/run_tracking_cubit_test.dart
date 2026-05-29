import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/services/location_source.dart';
import 'package:freshloop/state/run_tracking_cubit.dart';
import 'package:freshloop/state/run_tracking_state.dart';

class _FakeSource implements LocationSource {
  _FakeSource(this._controller, {this.granted = true});
  final StreamController<RoutePoint> _controller;
  final bool granted;
  @override
  Future<bool> ensurePermission() async => granted;
  @override
  Stream<RoutePoint> positions() => _controller.stream;
  @override
  Future<RoutePoint?> current() async => granted ? const RoutePoint(lat: 45.0, lng: 9.0) : null;
}

void main() {
  group('RunTrackingCubit', () {
    test('starts idle', () {
      final cubit = RunTrackingCubit(_FakeSource(StreamController<RoutePoint>()));
      expect(cubit.state, isA<RunIdle>());
      cubit.close();
    });

    test('emits permission-denied when permission is refused', () async {
      final cubit = RunTrackingCubit(_FakeSource(StreamController<RoutePoint>(), granted: false));
      await cubit.start();
      expect(cubit.state, isA<RunPermissionDenied>());
      await cubit.close();
    });

    test('accumulates distance from the position stream, then finishes', () async {
      final controller = StreamController<RoutePoint>();
      final cubit = RunTrackingCubit(_FakeSource(controller));
      await cubit.start();
      expect(cubit.state, isA<RunInProgress>());

      controller.add(const RoutePoint(lat: 45.0, lng: 9.0));
      await Future<void>.delayed(Duration.zero);
      controller.add(const RoutePoint(lat: 45.001, lng: 9.0)); // ~111 m further
      await Future<void>.delayed(Duration.zero);

      final progress = cubit.state as RunInProgress;
      expect(progress.distanceM, closeTo(111.2, 1.0));
      expect(progress.points.length, 2);

      cubit.stop();
      final finished = cubit.state as RunFinished;
      expect(finished.record.distanceM, closeTo(111.2, 1.0));
      expect(finished.record.points.length, 2);
      expect(finished.record.startedAt, isNotNull); // stamped at start, for history
      await cubit.close();
      await controller.close();
    });
  });
}
