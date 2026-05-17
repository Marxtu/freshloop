// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:freshloop/app/theme.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/features/tracking/tracking_screen.dart';
import 'package:freshloop/services/location_source.dart';
import 'mock_routes.dart';

class _DemoSource implements LocationSource {
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Stream<RoutePoint> positions() async* {
    for (final p in loop) {
      yield p;
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }
}

void main() => runApp(MaterialApp(
      theme: freshLoopTheme,
      debugShowCheckedModeBanner: false,
      home: TrackingScreen(locationSource: _DemoSource(), planned: mockRoute),
    ));
