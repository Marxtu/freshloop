import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/app/app.dart';

void main() {
  testWidgets('app launches and shows the home screen', (tester) async {
    await tester.pumpWidget(const FreshLoopApp());
    await tester.pumpAndSettle();
    expect(find.text('FreshLoop'), findsOneWidget);
    expect(find.byKey(const Key('home-tagline')), findsOneWidget);
  });
}
