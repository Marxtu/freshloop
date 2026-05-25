import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../domain/models/tier.dart';

/// A soft-tinted pill for one scoring axis: the axis icon (air / hills /
/// scenery) + label + tier word, coloured by tier. Conveys the result by icon,
/// text, AND colour — never colour alone (accessibility).
class AxisStat extends StatelessWidget {
  final String axis; // "Air", "Hills", "Scenery"
  final Tier tier;
  const AxisStat({super.key, required this.axis, required this.tier});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final st = axisStyle(axis, tier);
    return Semantics(
      label: '$axis ${st.word}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: st.container,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(st.icon, size: 15, color: st.color),
            const SizedBox(width: 5),
            Text(axis, style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Text(st.word,
                style: t.textTheme.labelMedium?.copyWith(color: st.color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
