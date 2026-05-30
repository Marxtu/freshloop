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

  /// True for Mapillary 360° equirectangular panoramas (shown with a badge and
  /// kept only as a fallback when no normal perspective shots are available).
  final bool isPano;

  /// A higher-resolution URL for the full-screen viewer (lazy-loaded on open).
  /// The carousel uses the small [url]; the viewer prefers [fullUrl] so a 360°
  /// panorama isn't a blurry 1024px image wrapped across the whole sphere.
  final String? fullUrl;

  const ScenePhoto({
    required this.url,
    required this.source,
    required this.lat,
    required this.lng,
    this.caption,
    this.isPano = false,
    this.fullUrl,
  });

  /// Parses one Mapillary `images` entry. `computed_geometry.coordinates` is
  /// `[lng, lat]`.
  factory ScenePhoto.fromMapillaryJson(Map<String, dynamic> json) {
    final coords = ((json['computed_geometry'] as Map<String, dynamic>?)?['coordinates']
            as List?) ??
        const [0, 0];
    final isPano = json['is_pano'] == true;
    return ScenePhoto(
      // Prefer the crisp 1024px thumb; fall back to 256 if absent.
      url: (json['thumb_1024_url'] ?? json['thumb_256_url']) as String,
      // High-res for the full-screen viewer. A 360° panorama is wrapped across
      // the whole sphere, so even 2048px looks soft (~5.7 px/°) — use the
      // original full-res equirectangular image. Perspective shots are crisp at
      // 2048px, so they don't need the heavier original.
      fullUrl: (isPano
              ? (json['thumb_original_url'] ?? json['thumb_2048_url'] ?? json['thumb_1024_url'])
              : (json['thumb_2048_url'] ?? json['thumb_1024_url'])) as String?,
      source: PhotoSource.mapillary,
      lng: (coords[0] as num).toDouble(),
      lat: (coords[1] as num).toDouble(),
      isPano: isPano,
    );
  }

  /// Builds a photo from one Wikimedia Commons geosearch result. The thumbnail
  /// URL is derived from the File title via Special:FilePath (no extra request).
  factory ScenePhoto.fromWikimediaGeosearch(Map<String, dynamic> json, {int width = 400}) {
    final filename = (json['title'] as String).replaceFirst('File:', '');
    final encoded = Uri.encodeComponent(filename);
    return ScenePhoto(
      url: 'https://commons.wikimedia.org/wiki/Special:FilePath/$encoded?width=$width',
      fullUrl: 'https://commons.wikimedia.org/wiki/Special:FilePath/$encoded?width=1600',
      source: PhotoSource.wikimedia,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lon'] as num).toDouble(),
      caption: filename,
    );
  }
}
