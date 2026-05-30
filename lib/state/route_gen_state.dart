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
  const RouteGenLoaded(this.routes);
}

class RouteGenError extends RouteGenState {
  final String message;
  const RouteGenError(this.message);
}
