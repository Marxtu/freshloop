/// Thrown when an external API returns a non-success response.
/// Carries enough context for callers to degrade gracefully (design doc §11).
class ApiException implements Exception {
  final String service;
  final int statusCode;
  final String body;

  ApiException(this.service, this.statusCode, this.body);

  @override
  String toString() => 'ApiException($service, status=$statusCode): $body';
}
