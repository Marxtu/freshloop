import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/models/scored_route.dart';
import '../services/favorites_repository.dart';

/// Reactive favourites: state is the current list of favourite routes.
class FavoritesCubit extends Cubit<List<ScoredRoute>> {
  final FavoritesRepository repo;
  FavoritesCubit(this.repo) : super(const []);

  Future<void> load() async => emit(await repo.all());

  bool isFavorite(String routeKey) => state.any((r) => r.routeKey == routeKey);

  Future<void> toggle(ScoredRoute route) async {
    if (isFavorite(route.routeKey)) {
      await repo.remove(route.routeKey);
    } else {
      await repo.add(route);
    }
    emit(await repo.all());
  }
}
