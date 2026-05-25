import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../domain/models/tier.dart';

/// A circular gauge for a 0–100 route score: a coloured arc proportional to the
/// score with the number in the centre. The arc colour follows the score's tier
/// (green / amber / red); the top-ranked candidate can [emphasize] in amber.
/// One clear metric — not chart-junk.
class ScoreGauge extends StatelessWidget {
  final double score;
  final double size;
  final bool emphasize;
  const ScoreGauge({super.key, required this.score, this.size = 72, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = emphasize ? AppColors.accent : axisStyle('', tierFromValue(score)).color;
    final stroke = size * 0.11;
    // One high-impact moment: the ring sweeps to the score on first appear.
    // The number is the static `child` (not rebuilt each frame) so it reads
    // immediately and text assertions don't depend on the animation.
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: (score / 100).clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, progress, child) => CustomPaint(
          painter: _GaugePainter(
            progress: progress,
            color: color,
            track: color.withValues(alpha: 0.16),
            stroke: stroke,
          ),
          child: child,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.round().toString(),
                style: t.textTheme.headlineSmall?.copyWith(
                  fontSize: size * 0.34,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text('score',
                  style: t.textTheme.labelSmall?.copyWith(
                    fontSize: size * 0.13,
                    color: t.colorScheme.onSurfaceVariant,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  final double stroke;
  _GaugePainter({required this.progress, required this.color, required this.track, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawCircle(center, radius, base);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    const start = -math.pi / 2; // 12 o'clock
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress || old.color != color || old.track != track || old.stroke != stroke;
}
