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

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(MaterialApp(home: HistoryScreen(repo: _FakeRepo([]))));
    await tester.pumpAndSettle();
    expect(find.textContaining('No runs yet'), findsOneWidget);
  });
}
