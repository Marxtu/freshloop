import 'package:flutter/material.dart';
import '../../data/routing/route_geometry.dart';

/// A minimal elevation profile: one filled line, no axes clutter (the course's
/// "too many chart elements" anti-pattern). Heights normalize to the route's
/// own min/max. Shows a hint when no elevation data is available.
class ElevationChart extends StatelessWidget {
  final List<RoutePoint> points;
  final double height;
  const ElevationChart({super.key, required this.points, this.height = 96});

  @override
  Widget build(BuildContext context) {
    final elevations = [
      for (final p in points)
        if (p.elevation != null) p.elevation!,
    ];
    if (elevations.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No elevation data', style: Theme.of(context).textTheme.bodySmall),
        ),
      );
    }
    final lo = elevations.reduce((a, b) => a < b ? a : b);
    final hi = elevations.reduce((a, b) => a > b ? a : b);
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ElevationPainter(elevations, Theme.of(context).colorScheme.primary),
            ),
          ),
          // Just the peak and valley — no other chart elements (anti-pattern: chart junk).
          Positioned(top: 2, right: 4, child: Text('${hi.round()} m', style: labelStyle)),
          Positioned(bottom: 2, right: 4, child: Text('${lo.round()} m', style: labelStyle)),
        ],
      ),
    );
  }
}

class _ElevationPainter extends CustomPainter {
  final List<double> elevations;
  final Color color;
  _ElevationPainter(this.elevations, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final lo = elevations.reduce((a, b) => a < b ? a : b);
    final hi = elevations.reduce((a, b) => a > b ? a : b);
    final span = (hi - lo).abs() < 1 ? 1.0 : hi - lo;
    final dx = size.width / (elevations.length - 1);
    Offset at(int i) => Offset(
          dx * i,
          size.height - ((elevations[i] - lo) / span) * (size.height - 8) - 4,
        );

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < elevations.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ElevationPainter old) =>
      old.elevations != elevations || old.color != color;
}
