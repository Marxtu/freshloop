import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/scored_route.dart';

abstract class FavoritesRepository {
  Future<void> add(ScoredRoute route);
  Future<void> remove(String routeKey);
  Future<List<ScoredRoute>> all();
  Future<bool> isFavorite(String routeKey);
}

class SharedPrefsFavoritesRepository implements FavoritesRepository {
  static const _key = 'favorites_v1';
  final SharedPreferences _prefs;
  SharedPrefsFavoritesRepository(this._prefs);

  List<ScoredRoute> _load() {
    final raw = _prefs.getStringList(_key) ?? const [];
    final routes = <ScoredRoute>[];
    for (final s in raw) {
      try {
        routes.add(ScoredRoute.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {
        // Skip a corrupt or legacy entry rather than failing the whole list.
      }
    }
    return routes;
  }

  Future<void> _store(List<ScoredRoute> routes) =>
      _prefs.setStringList(_key, routes.map((r) => jsonEncode(r.toJson())).toList());

  @override
  Future<List<ScoredRoute>> all() async => _load();

  @override
  Future<bool> isFavorite(String routeKey) async =>
      _load().any((r) => r.routeKey == routeKey);

  @override
  Future<void> add(ScoredRoute route) async {
    final routes = _load();
    if (routes.any((r) => r.routeKey == route.routeKey)) return;
    routes.add(route);
    await _store(routes);
  }

  @override
  Future<void> remove(String routeKey) async {
    final routes = _load()..removeWhere((r) => r.routeKey == routeKey);
    await _store(routes);
  }
}
