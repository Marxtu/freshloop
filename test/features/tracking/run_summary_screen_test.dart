import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/models/run_record.dart';
import 'package:freshloop/features/tracking/run_summary_screen.dart';

void main() {
  testWidgets('shows distance, time, pace for a finished run', (tester) async {
    const record = RunRecord(
      points: [RoutePoint(lat: 45.0, lng: 9.0), RoutePoint(lat: 45.001, lng: 9.0)],
      distanceM: 2000,
      durationS: 600,
    );
    await tester.pumpWidget(const MaterialApp(home: RunSummaryScreen(record: record)));
    await tester.pump();
    expect(find.textContaining('2.00'), findsWidgets);   // km
    expect(find.text('10:00'), findsOneWidget);          // duration
    expect(find.text("5'00\""), findsOneWidget);         // pace
    expect(find.textContaining('Done'), findsOneWidget);
  });
}
