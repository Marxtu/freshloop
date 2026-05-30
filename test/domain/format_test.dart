import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/domain/format.dart';

void main() {
  group('formatDuration', () {
    test('mm:ss under an hour', () {
      expect(formatDuration(0), '00:00');
      expect(formatDuration(65), '01:05');
    });
    test('h:mm:ss at/over an hour', () {
      expect(formatDuration(3725), '1:02:05');
    });
  });
  group('formatPace', () {
    test("min'sec\" per km", () {
      expect(formatPace(1000, 300), "5'00\"");
      expect(formatPace(2000, 600), "5'00\"");
    });
    test('placeholder when distance is ~0', () {
      expect(formatPace(0, 120), "--'--\"");
    });
  });
  group('formatDistance', () {
    test('metres under a km, one decimal under 10 km, whole km beyond', () {
      expect(formatDistance(120), '120 m');
      expect(formatDistance(999), '999 m');
      expect(formatDistance(1180), '1.2 km');
      expect(formatDistance(6500), '6.5 km');
      expect(formatDistance(12400), '12 km');
    });
  });
  group('formatRunDate', () {
    test('"day Mon year, HH:MM" with zero-padded time', () {
      expect(formatRunDate(DateTime(2026, 5, 28, 14, 32)), '28 May 2026, 14:32');
      expect(formatRunDate(DateTime(2026, 1, 3, 9, 5)), '3 Jan 2026, 09:05');
    });
  });
}
