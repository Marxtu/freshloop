import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/scored_route.dart';
import 'favorites_repository.dart';

/// Cloud-backed favourites under /users/{uid}/favorites/{routeKey}.
class FirestoreFavoritesRepository implements FavoritesRepository {
  final FirebaseFirestore _db;
  final String uid;
  FirestoreFavoritesRepository(this._db, this.uid);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('favorites');

  @override
  Future<void> add(ScoredRoute route) async => _col.doc(route.routeKey).set(route.toJson());
  @override
  Future<void> remove(String routeKey) async => _col.doc(routeKey).delete();
  @override
  Future<bool> isFavorite(String routeKey) async => (await _col.doc(routeKey).get()).exists;

  @override
  Future<List<ScoredRoute>> all() async {
    final snap = await _col.get();
    final out = <ScoredRoute>[];
    for (final d in snap.docs) {
      try {
        out.add(ScoredRoute.fromJson(d.data()));
      } catch (_) {/* skip a malformed doc */}
    }
    return out;
  }
}
