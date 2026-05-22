import 'dart:async';
import 'package:flutter/foundation.dart';

/// Bridges a [Stream] to go_router's `refreshListenable`: notifies listeners
/// (re-running the router's `redirect`) on every stream event. Standard
/// go_router pattern — used here to re-evaluate the auth gate on each
/// auth-state change.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _sub;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
