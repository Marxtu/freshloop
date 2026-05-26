import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/app/theme.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/services/location_source.dart';
import 'package:freshloop/features/tracking/tracking_screen.dart';

class _FakeSource implements LocationSource {
  _FakeSource(this.controller, {this.granted = true});
  final StreamController<RoutePoint> controller;
  final bool granted;
  @override
  Future<bool> ensurePermission() async => granted;
  @override
  Stream<RoutePoint> positions() => controller.stream;
  @override
  Future<RoutePoint?> current() async => granted ? const RoutePoint(lat: 45.0, lng: 9.0) : null;
}

void main() {
  testWidgets('shows live distance and a Stop control while tracking', (tester) async {
    final controller = StreamController<RoutePoint>.broadcast();
    await tester.pumpWidget(MaterialApp(
      theme: freshLoopTheme,
      home: TrackingScreen(locationSource: _FakeSource(controller)),
    ));
    await tester.pump(); // let start() resolve + first emit
    await tester.pump();

    controller.add(const RoutePoint(lat: 45.0, lng: 9.0));
    await tester.pump();
    controller.add(const RoutePoint(lat: 45.001, lng: 9.0)); // ~111 m
    await tester.pump();

    expect(find.textContaining('Stop'), findsOneWidget);
    expect(find.textContaining('0.11'), findsWidgets); // 0.11 km shown

    // dispose to cancel the ticker (no pending timers)
    await tester.pumpWidget(const SizedBox());
    await controller.close();
  });

  testWidgets('shows a permission message when location is denied', (tester) async {
    final controller = StreamController<RoutePoint>.broadcast();
    await tester.pumpWidget(MaterialApp(
      theme: freshLoopTheme,
      home: TrackingScreen(locationSource: _FakeSource(controller, granted: false)),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Location'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await controller.close();
  });
}
