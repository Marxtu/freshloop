import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/domain/models/tier.dart';

void main() {
  group('tierFromValue', () {
    test('67 and above is good', () {
      expect(tierFromValue(67), Tier.good);
      expect(tierFromValue(100), Tier.good);
    });
    test('34 to 66 is partial', () {
      expect(tierFromValue(34), Tier.partial);
      expect(tierFromValue(66), Tier.partial);
    });
    test('below 34 is poor', () {
      expect(tierFromValue(0), Tier.poor);
      expect(tierFromValue(33.9), Tier.poor);
    });
  });
}
