import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app/app_config.dart';
import '../data/air/open_meteo_air_client.dart';
import '../data/greenery/overpass_client.dart';
import '../data/photos/mapillary_client.dart';
import '../data/photos/wikimedia_client.dart';
import '../data/routing/ors_route_client.dart';
import '../services/auth_repository.dart';
import '../services/favorites_repository.dart';
import '../services/firebase_auth_repository.dart';
import '../services/firestore_favorites_repository.dart';
import '../services/firestore_run_history_repository.dart';
import '../services/photo_service.dart';
import '../services/route_generator.dart';
import '../services/run_history_repository.dart';

const _userAgent = 'FreshLoop/0.1 (course project)';

/// True only after `main()` successfully runs `Firebase.initializeApp`.
///
/// THE CRITICAL INVARIANT: while this is `false`, nothing may touch
/// `FirebaseAuth.instance` / `FirebaseFirestore.instance` — they throw without
/// an initialized Firebase app. Every factory below short-circuits on it so the
/// app (and the tests, which never initialize Firebase) fall back to M5.1 local
/// storage.
bool firebaseReady = false;

/// Builds the production RouteGenerator from real clients + configured keys.
RouteGenerator buildRouteGenerator() => RouteGenerator(
      ors: OrsRouteClient(apiKey: AppConfig.orsApiKey),
      air: OpenMeteoAirClient(),
      overpass: OverpassClient(userAgent: _userAgent),
    );

PhotoService buildPhotoService() => PhotoService(
      mapillary: MapillaryPhotoClient(accessToken: AppConfig.mapillaryToken),
      wikimedia: WikimediaPhotoClient(userAgent: _userAgent),
    );

late final SharedPreferences appPrefs; // set in main() before runApp

/// Firebase Auth backed repository. Only call when [firebaseReady] is true.
AuthRepository buildAuthRepository() => FirebaseAuthRepository(FirebaseAuth.instance);

/// Cloud history scoped to the signed-in uid; otherwise local storage.
RunHistoryRepository buildHistoryRepository() {
  final uid = firebaseReady ? FirebaseAuth.instance.currentUser?.uid : null;
  return uid != null
      ? FirestoreRunHistoryRepository(FirebaseFirestore.instance, uid)
      : SharedPrefsRunHistoryRepository(appPrefs);
}

/// Cloud favourites scoped to the signed-in uid; otherwise local storage.
FavoritesRepository buildFavoritesRepository() {
  final uid = firebaseReady ? FirebaseAuth.instance.currentUser?.uid : null;
  return uid != null
      ? FirestoreFavoritesRepository(FirebaseFirestore.instance, uid)
      : SharedPrefsFavoritesRepository(appPrefs);
}
