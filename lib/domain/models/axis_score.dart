import 'tier.dart';

/// One axis result: its 0-100 value and the tier derived from it.
class AxisScore {
  final double value;
  final Tier tier;

  AxisScore(this.value) : tier = tierFromValue(value);
}
