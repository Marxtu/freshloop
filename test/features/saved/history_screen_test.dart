import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/models/run_record.dart';
import 'package:freshloop/features/saved/history_screen.dart';
import 'package:freshloop/services/run_history_repository.dart';

class _FakeRepo implements RunHistoryRepository {
  final List<RunRecord> _runs;
  _FakeRepo(this._runs);
  @override
  Future<List<RunRecord>> all() async => _runs;
  @override
  Future<void> save(RunRecord r) async => _runs.add(r);
}

void main() {
  testWidgets('lists saved runs', (tester) async {
    final repo = _FakeRepo([
      const RunRecord(points: [RoutePoint(lat: 1, lng: 2)], distanceM: 5000, durationS: 1500),
    ]);
    await tester.pumpWidget(MaterialApp(home: HistoryScreen(repo: repo)));
    await tester.pumpAndSettle();
    expect(find.textContaining('5.00 km'), findsOneWidget);
    expect(find.textContaining('25:00'), findsOneWidget);
  });

  testWidgets('shows the run date and opens details on tap', (tester) async {
    final repo = _FakeRepo([
      RunRecord(
        points: const [RoutePoint(lat: 45.0, lng: 9.0), RoutePoint(lat: 45.001, lng: 9.0)],
        distanceM: 5000,
        durationS: 1500,
        startedAt: DateTime(2026, 5, 28, 14, 32),
      ),
    ]);
    await tester.pumpWidget(MaterialApp(home: HistoryScreen(repo: repo)));
    await tester.pumpAndSettle();
    expect(find.text('28 May 2026, 14:32'), findsOneWidget); // date surfaced in the list

    await tester.tap(find.text('5.00 km'));
    // RouteMap tiles never settle under test, so pump a bounded number of frames.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Run details'), findsOneWidget); // navigated into the detail screen
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(MaterialApp(home: HistoryScreen(repo: _FakeRepo([]))));
    await tester.pumpAndSettle();
    expect(find.textContaining('No runs yet'), findsOneWidget);
  });
}
