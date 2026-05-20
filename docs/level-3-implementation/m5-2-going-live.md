# FreshLoop M5.2 — Going live (the remaining gated step)

> M5.2 built the auth layer (`AppUser`, `AuthRepository`, `AuthCubit`, `SignInScreen`)
> and Firebase implementations (`FirebaseAuthRepository`, `FirestoreRunHistoryRepository`,
> `FirestoreFavoritesRepository`), all **mock-tested** with `firebase_auth_mocks` and
> `fake_cloud_firestore`. The running app was deliberately **left on M5.1 local storage**:
> `main.dart`, `lib/app/router.dart`, and the existing parts of `lib/app/dependencies.dart`
> are untouched, there is no call to `Firebase.initializeApp`, and there is no
> `lib/firebase_options.dart`.
>
> This document captures exactly what is left to connect a real Firebase project, so the
> switch is unambiguous when a project + credentials are available.

## Prerequisites

- A Firebase project in the console with a **Firestore database created** (Native mode).
- **Email/Password** enabled under Authentication → Sign-in method.
- `firebase-tools` and `flutterfire_cli` installed
  (`dart pub global activate flutterfire_cli`, `npm i -g firebase-tools`).

## Steps

### 1. Generate `lib/firebase_options.dart`

Run `flutterfire configure` (selects the project and platforms). This writes a
**gitignored** `lib/firebase_options.dart` containing the platform options. Do **not**
commit it — it carries project identifiers and is regenerated per environment.

### 2. Initialise Firebase in `main()` (guarded, with a `firebaseReady` flag)

Make `main()` initialise Firebase inside a `try/catch` so the app still boots (on M5.1
local storage) when no project/credentials are present:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

bool firebaseReady = false; // read by dependencies.dart

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  appPrefs = await SharedPreferences.getInstance();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseReady = true;
  } catch (_) {
    firebaseReady = false; // graceful fallback to local storage
  }
  runApp(const FreshLoopApp());
}
```

### 3. Add an `AuthGate` at the router root

Provide an `AuthCubit` (built from `FirebaseAuthRepository(FirebaseAuth.instance)`) above
the app, then gate the root on `AuthState.status`:

- `AuthStatus.unknown` → a splash / loading screen,
- `AuthStatus.signedOut` → `SignInScreen`,
- `AuthStatus.signedIn` → the current `HomeScreen` (existing router).

When `firebaseReady == false`, skip the gate entirely and route straight to the current
home so the app keeps working with no project.

### 4. Swap the repositories in `dependencies.dart` when signed in

Keep the M5.1 `SharedPrefs*` repositories as the fallback. When Firebase is ready and a
user is signed in, build the cloud repositories scoped to the user id:

```dart
RunHistoryRepository buildHistoryRepository() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (firebaseReady && uid != null) {
    return FirestoreRunHistoryRepository(FirebaseFirestore.instance, uid);
  }
  return SharedPrefsRunHistoryRepository(appPrefs);
}

FavoritesRepository buildFavoritesRepository() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (firebaseReady && uid != null) {
    return FirestoreFavoritesRepository(FirebaseFirestore.instance, uid);
  }
  return SharedPrefsFavoritesRepository(appPrefs);
}
```

(Note: the `/favorites` route currently builds its own repository via the
`FavoritesCubit` wiring — route both history and favourites through these builders so the
swap is centralised.)

### 5. Console + rules

- Authentication → Sign-in method → enable **Email/Password**.
- Firestore database is created (prerequisite).
- Deploy the security rules in `firestore.rules` (at repo root):
  `firebase deploy --only firestore:rules`
  The rules restrict `/users/{userId}/**` to the owning, authenticated user — matching the
  `/users/{uid}/runs/{autoId}` and `/users/{uid}/favorites/{routeKey}` data model the
  Firestore repositories write to.

### 6. A sign-out action in the UI

Add a sign-out entry somewhere reachable (e.g. a profile/menu item on the home screen)
that calls `context.read<AuthCubit>().signOut()`. The `AuthGate` then returns the user to
`SignInScreen` automatically via the auth state stream.

## Verification after going live

- `flutter analyze` clean; `flutter test` green (the mock-based tests are unaffected).
- Sign up → land on home; record a run / favourite a route → it appears under
  `/users/{uid}/runs` and `/users/{uid}/favorites` in the Firestore console.
- Sign out → returns to `SignInScreen`; sign in as a different user → sees only their own
  data (per-user isolation, enforced by both the path scoping and the rules).
