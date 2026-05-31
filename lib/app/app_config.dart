/// Compile-time configuration. Values come from `--dart-define-from-file=secrets.json`
/// (gitignored). Empty strings mean the key was not provided — clients that need a
/// key should fail clearly rather than calling an API unauthenticated.
class AppConfig {
  const AppConfig._();

  /// OpenRouteService API key (sent as the `Authorization` header).
  static const String orsApiKey = String.fromEnvironment('ORS_API_KEY');

  /// Contact string sent as the `User-Agent` for the OSM-based geocoders
  /// (Photon for type-ahead; the policies ask for a descriptive agent).
  /// See https://operations.osmfoundation.org/policies/nominatim/
  static const String geocoderUserAgent =
      String.fromEnvironment('NOMINATIM_USER_AGENT', defaultValue: 'FreshLoop/0.1 (course project)');

  /// Mapillary access token (sent as the `Authorization: OAuth <token>` header).
  static const String mapillaryToken = String.fromEnvironment('MAPILLARY_TOKEN');
}
