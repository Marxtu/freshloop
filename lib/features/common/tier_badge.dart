import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../domain/models/tier.dart';

/// A small chip showing an axis result: a coloured dot + a text label
/// (never colour alone). [axis] is e.g. "Air", "Hills", "Scenery".
class TierBadge extends StatelessWidget {
  final String axis;
  final Tier tier;
  const TierBadge({super.key, required this.axis, required this.tier});

  Color get _color => switch (tier) {
        Tier.good => AppColors.tierGood,
        Tier.partial => AppColors.tierPartial,
        Tier.poor => AppColors.tierPoor,
      };

  String get _label => switch (tier) {
        Tier.good => 'good',
        Tier.partial => 'ok',
        Tier.poor => 'poor',
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$axis $_label',
      child: Chip(
        avatar: CircleAvatar(backgroundColor: _color, radius: 6),
        label: Text('$axis · $_label'),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
