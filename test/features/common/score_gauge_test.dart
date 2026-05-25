import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/app/theme.dart';
import 'package:freshloop/features/common/score_gauge.dart';

void main() {
  testWidgets('renders the rounded score and label', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: freshLoopTheme,
      home: const Scaffold(body: Center(child: ScoreGauge(score: 86.4))),
    ));
    expect(find.text('86'), findsOneWidget); // rounded
    expect(find.text('score'), findsOneWidget);
  });

  testWidgets('emphasized gauge still renders the score', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: freshLoopTheme,
      home: const Scaffold(body: Center(child: ScoreGauge(score: 99, emphasize: true))),
    ));
    expect(find.text('99'), findsOneWidget);
  });
}
