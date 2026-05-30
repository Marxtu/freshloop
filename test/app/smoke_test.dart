import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/app/app.dart';

void main() {
  testWidgets('app boots with the FreshLoop theme', (tester) async {
    await tester.pumpWidget(const FreshLoopApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
