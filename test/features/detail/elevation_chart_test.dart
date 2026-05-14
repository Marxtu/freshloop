import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/features/detail/elevation_chart.dart';

void main() {
  testWidgets('renders a CustomPaint for a route with elevations', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ElevationChart(points: [
          RoutePoint(lat: 0, lng: 0, elevation: 100),
          RoutePoint(lat: 0, lng: 0, elevation: 130),
          RoutePoint(lat: 0, lng: 0, elevation: 110),
        ]),
      ),
    ));
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('shows a no-data hint when elevations are missing', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ElevationChart(points: [RoutePoint(lat: 0, lng: 0)])),
    ));
    expect(find.text('No elevation data'), findsOneWidget);
  });
}
