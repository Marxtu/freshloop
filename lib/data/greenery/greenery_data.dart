/// Greenery assessment for a route corridor, derived from OSM/Overpass features.
/// [greenRatio] and [scenicWaypoints] are the scoring inputs (design doc §6);
/// the ratio is a documented heuristic proxy (green-feature count normalized),
/// not a true area-coverage measurement.
class GreeneryData {
  final int greenCount;
  final int scenicCount;

  const GreeneryData({required this.greenCount, required this.scenicCount});

  /// 0..1 proxy: ~8 green features in the corridor is treated as "fully green".
  double get greenRatio => (greenCount / 8).clamp(0, 1).toDouble();

  /// Scenic points passed (the scoring layer caps the useful range).
  int get scenicWaypoints => scenicCount;

  static const _greenLanduse = {'forest', 'grass', 'meadow', 'recreation_ground', 'village_green'};
  static const _greenNatural = {'wood', 'water', 'grassland', 'scrub'};
  static const _scenicTourism = {'viewpoint', 'attraction'};

  /// Counts green features and scenic POIs from an Overpass `out:json` response.
  factory GreeneryData.fromOverpassJson(Map<String, dynamic> json) {
    final elements = (json['elements'] as List?) ?? const [];
    var green = 0;
    var scenic = 0;
    for (final e in elements) {
      final tags = ((e as Map<String, dynamic>)['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
      if (tags['leisure'] == 'park' ||
          _greenLanduse.contains(tags['landuse']) ||
          _greenNatural.contains(tags['natural'])) {
        green++;
      }
      if (_scenicTourism.contains(tags['tourism']) ||
          tags['natural'] == 'peak' ||
          tags.containsKey('historic')) {
        scenic++;
      }
    }
    return GreeneryData(greenCount: green, scenicCount: scenic);
  }
}
