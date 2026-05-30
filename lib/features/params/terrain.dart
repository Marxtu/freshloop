/// How hilly the runner wants the route. Maps to a target cumulative ascent.
enum Terrain { flat, rolling, hilly }

/// Target ascent (metres) for [terrain] over [distanceM]: flat=0, rolling≈12 m/km,
/// hilly≈30 m/km. Feeds RunParams.targetAscentM (scored against actual ascent).
double targetAscentFor(Terrain terrain, double distanceM) {
  final km = distanceM / 1000;
  switch (terrain) {
    case Terrain.flat:
      return 0;
    case Terrain.rolling:
      return 12 * km;
    case Terrain.hilly:
      return 30 * km;
  }
}
