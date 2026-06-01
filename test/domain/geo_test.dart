import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/geo.dart';

void main() {
  const pts = [
    RoutePoint(lat: 45.46, lng: 9.18),
    RoutePoint(lat: 45.48, lng: 9.22),
    RoutePoint(lat: 45.47, lng: 9.20),
  ];

  group('destinationPoint', () {
    const milan = RoutePoint(lat: 45.46, lng: 9.19);
    test('east moves longitude up, latitude ~unchanged, at about the distance', () {
      final e = destinationPoint(milan, 90, 2000);
      expect(e.lat, closeTo(45.46, 1e-4));
      expect(e.lng, greaterThan(9.19));
      expect(haversineMeters(milan, e), closeTo(2000, 30));
    });
    test('north moves latitude up by ~distance', () {
      final n = destinationPoint(milan, 0, 1000);
      expect(n.lat, greaterThan(45.46));
      expect(n.lng, closeTo(9.19, 1e-9));
      expect(haversineMeters(milan, n), closeTo(1000, 15));
    });
  });

  group('ascentOf', () {
    test('sums only the positive elevation deltas', () {
      const climb = [
        RoutePoint(lat: 0, lng: 0, elevation: 100),
        RoutePoint(lat: 0, lng: 0, elevation: 130), // +30
        RoutePoint(lat: 0, lng: 0, elevation: 110), // -20 (ignored)
        RoutePoint(lat: 0, lng: 0, elevation: 150), // +40
      ];
      expect(ascentOf(climb), closeTo(70, 1e-9));
    });
    test('is zero when elevations are missing', () {
      expect(ascentOf(const [RoutePoint(lat: 0, lng: 0), RoutePoint(lat: 1, lng: 1)]), 0);
    });
  });

  group('boundingBoxOf', () {
    test('computes min/max with padding', () {
      final b = boundingBoxOf(pts, padDeg: 0.0);
      expect(b.south, 45.46);
      expect(b.north, 45.48);
      expect(b.west, 9.18);
      expect(b.east, 9.22);
    });
    test('applies padding outward', () {
      final b = boundingBoxOf(pts, padDeg: 0.01);
      expect(b.south, closeTo(45.45, 1e-9));
      expect(b.east, closeTo(9.23, 1e-9));
    });
    test('throws on empty', () {
      expect(() => boundingBoxOf(const []), throwsArgumentError);
    });
  });

  group('subsample', () {
    test('returns all when within max', () {
      expect(subsample(pts, 10).length, 3);
    });
    test('reduces to max and keeps first and last', () {
      final many = List.generate(100, (i) => RoutePoint(lat: i.toDouble(), lng: 0));
      final s = subsample(many, 10);
      expect(s.length, 10);
      expect(s.first.lat, 0);
      expect(s.last.lat, 99);
    });
    test('max of 1 returns just the first point (no divide-by-zero)', () {
      expect(subsample(pts, 1), [pts.first]);
    });
    test('returns input unchanged for empty', () {
      expect(subsample(const [], 5), isEmpty);
    });
  });
}
