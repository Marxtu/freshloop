import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/app/theme.dart';
import 'package:freshloop/domain/models/run_params.dart';
import 'package:freshloop/features/params/params_sheet.dart';

void main() {
  testWidgets('shows controls and emits RunParams on Generate', (tester) async {
    RunParams? captured;
    await tester.pumpWidget(MaterialApp(
      theme: freshLoopTheme,
      home: Scaffold(
        body: ParamsSheet(
          startLat: 45.46,
          startLng: 9.19,
          onGenerate: (p) => captured = p,
        ),
      ),
    ));

    expect(find.text('Generate routes'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(4)); // distance + 3 weights

    await tester.tap(find.text('Generate routes'));
    await tester.pump();

    expect(captured, isNotNull);
    expect(captured!.startLat, 45.46);
    expect(captured!.targetDistanceM, greaterThan(0));
  });
}
