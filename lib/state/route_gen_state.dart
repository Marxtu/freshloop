import '../domain/models/scored_route.dart';

/// States for the route-generation flow (design doc §7).
sealed class RouteGenState {
  const RouteGenState();
}

class RouteGenInitial extends RouteGenState {
  const RouteGenInitial();
}

class RouteGenLoading extends RouteGenState {
  const RouteGenLoading();
}

class RouteGenLoaded extends RouteGenState {
  final List<ScoredRoute> routes;

  /// The distance the user asked for (metres), so the UI can flag when even the
  /// closest generated loop is far off (a sparse trail network around the start).
  final double? targetDistanceM;

  const RouteGenLoaded(this.routes, {this.targetDistanceM});
}

class RouteGenError extends RouteGenState {
  final String message;
  const RouteGenError(this.message);
}
