/// Elevation sub-score: rewards routes whose cumulative ascent is close to the
/// runner's *target* ascent (flat for beginners, hilly for training). This is a
/// preference match, not "flatter is always better".
///
/// The score falls off linearly as actual ascent diverges from [targetAscentM],
/// scaled by a reference of at least 50 m so a flat target stays meaningful.
double hillsScore({required double actualAscentM, required double targetAscentM}) {
  final diff = (actualAscentM - targetAscentM).abs();
  final refScale = targetAscentM > 50 ? targetAscentM : 50.0;
  return (100 - (diff / refScale) * 100).clamp(0, 100).toDouble();
}
