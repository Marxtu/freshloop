import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/domain/models/run_record.dart';

void main() {
  group('RunRecord.paceSecPerKm', () {
    test('300 s over 1 km is 300 s/km', () {
      const r = RunRecord(points: [], distanceM: 1000, durationS: 300);
      expect(r.paceSecPerKm, 300);
    });
    test('zero distance yields zero pace (no divide-by-zero)', () {
      const r = RunRecord(points: [], distanceM: 0, durationS: 120);
      expect(r.paceSecPerKm, 0);
    });
  });
}
