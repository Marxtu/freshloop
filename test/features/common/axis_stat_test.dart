import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/app/theme.dart';
import 'package:freshloop/domain/models/tier.dart';
import 'package:freshloop/features/common/axis_stat.dart';

void main() {
  testWidgets('shows the axis, the tier word, and the matching icon', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: freshLoopTheme,
      home: const Scaffold(body: AxisStat(axis: 'Air', tier: Tier.good)),
    ));
    expect(find.text('Air'), findsOneWidget);
    expect(find.text('good'), findsOneWidget);
    expect(find.byIcon(Icons.air_rounded), findsOneWidget);
  });

  testWidgets('maps each tier to its word', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: freshLoopTheme,
      home: const Scaffold(
        body: Column(children: [
          AxisStat(axis: 'Hills', tier: Tier.partial),
          AxisStat(axis: 'Scenery', tier: Tier.poor),
        ]),
      ),
    ));
    expect(find.text('ok'), findsOneWidget); // partial
    expect(find.text('poor'), findsOneWidget);
    expect(find.byIcon(Icons.terrain_rounded), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_back_rounded), findsOneWidget);
  });
}
