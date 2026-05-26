/// Where a scenery photo came from.
enum PhotoSource { mapillary, wikimedia }

/// A photo shown along a route (design doc §8). [url] is a directly displayable
/// thumbnail; [lat]/[lng] locate it; [caption] is optional.
class ScenePhoto {
  final String url;
  final PhotoSource source;
  final double lat;
  final double lng;
  final String? caption;

  const ScenePhoto({
    required this.url,
    required this.source,
    required this.lat,
    required this.lng,
    this.caption,
  });

  /// Parses one Mapillary `images` entry. `computed_geometry.coordinates` is
  /// `[lng, lat]`.
  factory ScenePhoto.fromMapillaryJson(Map<String, dynamic> json) {
    final coords = ((json['computed_geometry'] as Map<String, dynamic>?)?['coordinates']
            as List?) ??
        const [0, 0];
    return ScenePhoto(
      // Prefer the crisp 1024px thumb; fall back to 256 if absent.
      url: (json['thumb_1024_url'] ?? json['thumb_256_url']) as String,
      source: PhotoSource.mapillary,
      lng: (coords[0] as num).toDouble(),
      lat: (coords[1] as num).toDouble(),
    );
  }

  /// Builds a photo from one Wikimedia Commons geosearch result. The thumbnail
  /// URL is derived from the File title via Special:FilePath (no extra request).
  factory ScenePhoto.fromWikimediaGeosearch(Map<String, dynamic> json, {int width = 400}) {
    final filename = (json['title'] as String).replaceFirst('File:', '');
    final encoded = Uri.encodeComponent(filename);
    return ScenePhoto(
      url: 'https://commons.wikimedia.org/wiki/Special:FilePath/$encoded?width=$width',
      source: PhotoSource.wikimedia,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lon'] as num).toDouble(),
      caption: filename,
    );
  }
}
