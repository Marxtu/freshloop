import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/features/params/terrain.dart';

void main() {
  group('targetAscentFor', () {
    test('flat is 0 regardless of distance', () {
      expect(targetAscentFor(Terrain.flat, 5000), 0);
    });
    test('rolling is ~12 m per km', () {
      expect(targetAscentFor(Terrain.rolling, 5000), 60); // 12 * 5km
    });
    test('hilly is ~30 m per km', () {
      expect(targetAscentFor(Terrain.hilly, 5000), 150); // 30 * 5km
    });
  });
}
