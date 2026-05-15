import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/geo.dart';

void main() {
  group('haversineMeters', () {
    test('zero for identical points', () {
      expect(haversineMeters(const RoutePoint(lat: 45.46, lng: 9.19),
          const RoutePoint(lat: 45.46, lng: 9.19)), 0);
    });
    test('~111 m for 0.001 degree of latitude', () {
      final d = haversineMeters(const RoutePoint(lat: 45.0, lng: 9.0),
          const RoutePoint(lat: 45.001, lng: 9.0));
      expect(d, closeTo(111.2, 1.0));
    });
    test('~111 km for 1 degree of longitude at the equator', () {
      final d = haversineMeters(const RoutePoint(lat: 0, lng: 0),
          const RoutePoint(lat: 0, lng: 1));
      expect(d, closeTo(111320, 200));
    });
  });
}
