import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freshloop/app/app.dart';
import 'package:freshloop/app/dependencies.dart';

void main() {
  setUp(() async {
    firebaseReady = false; // ensure local mode — no Firebase init in tests
    SharedPreferences.setMockInitialValues({});
    appPrefs = await SharedPreferences.getInstance();
  });

  testWidgets('app boots with the FreshLoop theme', (tester) async {
    await tester.pumpWidget(const FreshLoopApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
