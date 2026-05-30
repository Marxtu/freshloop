import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/models/run_record.dart';
import 'package:freshloop/services/run_history_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saves runs and lists them newest-first', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPrefsRunHistoryRepository(prefs);

    expect(await repo.all(), isEmpty);
    await repo.save(const RunRecord(points: [RoutePoint(lat: 1, lng: 2)], distanceM: 1000, durationS: 300));
    await repo.save(const RunRecord(points: [], distanceM: 2000, durationS: 600));

    final all = await repo.all();
    expect(all.length, 2);
    expect(all.first.distanceM, 2000); // newest first
  });

  test('skips a corrupt entry instead of failing the whole history', () async {
    SharedPreferences.setMockInitialValues({
      'run_history_v1': [
        'not valid json',
        jsonEncode(const RunRecord(points: [], distanceM: 1500, durationS: 450).toJson()),
      ],
    });
    final repo = SharedPrefsRunHistoryRepository(await SharedPreferences.getInstance());

    final all = await repo.all();
    expect(all.length, 1);
    expect(all.first.distanceM, 1500);
  });
}
