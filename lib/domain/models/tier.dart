/// Quality tier for one scoring axis, mirroring the WHO 3-tier rubric
/// (Meets +++ / Partial ++ / Does not meet +). See design doc section 6.
enum Tier { good, partial, poor }

/// Maps a 0-100 score value to a [Tier] using three bands.
Tier tierFromValue(double value) {
  if (value >= 67) return Tier.good;
  if (value >= 34) return Tier.partial;
  return Tier.poor;
}
