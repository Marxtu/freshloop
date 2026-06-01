# FreshLoop M5.2 — Going live (the remaining gated step)

> **STATUS (M5.3, 2026-05-31): the runtime wiring is DONE.** Project
> `freshloop-86034` is configured (`lib/firebase_options.dart` committed,
> `android/app/google-services.json` generated, google-services Gradle plugin
> applied). M5.3 turned on the M5.2 code: guarded `Firebase.initializeApp`, the
> auth gate, the uid-scoped cloud repositories, and the sign-out action are all
> implemented and tested. **Steps 1–4 and 6 below are DONE.** Only the two
> console actions in step 5 remain; they require the project owner.

> M5.2 built the auth layer (`AppUser`, `AuthRepository`, `AuthCubit`, `SignInScreen`)
> and Firebase implementations (`FirebaseAuthRepository`, `FirestoreRunHistoryRepository`,
> `FirestoreFavoritesRepository`), all **mock-tested** with `firebase_auth_mocks` and
> `fake_cloud_firestore`. M5.2 deliberately left the running app on M5.1 local storage;
> **M5.3 wired it all in behind a `firebaseReady` flag** so the app still boots on local
> storage whenever Firebase is unavailable (tests, web screenshots, fresh clones).
>
> This document captures the connect-a-real-project steps; the code-side steps are now
> implemented, with the remaining work being the owner-only console actions.

## Prerequisites

- A Firebase project in the console with a **Firestore database created** (Native mode).
- **Email/Password** enabled under Authentication → Sign-in method.
- `firebase-tools` and `flutterfire_cli` installed
  (`dart pub global activate flutterfire_cli`, `npm i -g firebase-tools`).

## Steps

### 1. Generate `lib/firebase_options.dart` — DONE

Run `flutterfire configure` (selects the project and platforms). This writes
`lib/firebase_options.dart` (committed in M5.3; Firebase client config is **not**
secret per Google, and committing it lets a clean clone compile) plus the native
`android/app/google-services.json` (kept **gitignored**; regenerate it via
`flutterfire configure` for Android builds, since `flutter test` and `flutter build web`
do not need it). **To connect a different project, just re-run `flutterfire configure`**;
it rewrites `firebase_options.dart`, `firebase.json`, and `google-services.json`.

### 2. Initialise Firebase in `main()` (guarded, with a `firebaseReady` flag) — DONE

`main()` initialises Firebase inside a `try/catch` so the app still boots (on M5.1
local storage) when no project/credentials are present. `firebaseReady` lives in
`lib/app/dependencies.dart` (default `false`); `main()` sets it `true` only after a
successful `Firebase.initializeApp`. Implemented as:

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

### 3. Add an `AuthGate` at the router root — DONE

Implemented as a go_router `redirect` rather than a wrapper widget. `lib/app/app.dart`
runs in two modes: **local mode** (`!firebaseReady` and no injected `authRepository`) is
exactly the M5.1 tree (no `AuthCubit`, no Firebase touched, which keeps the smoke test green);
**Firebase mode** (`firebaseReady`, or an `authRepository` is injected for tests) provides
an `AuthCubit` above a single, stable `MaterialApp.router`. `appRouter` became
`buildRouter()` (a function, so no Firebase singleton is read at library-load time). When
the gate is enabled the `redirect` is driven by the in-scope `AuthCubit` state
(`signedOut` → `/sign-in`; `signedIn` & at `/sign-in` → `/`; `unknown` → no redirect), and
a `GoRouterRefreshStream` over the `AuthCubit.stream` re-runs the gate on each auth change.
Reading the cubit (not `FirebaseAuth.instance`) lets the auth-gate widget test drive the
gate with an injected fake, with no real Firebase. When `firebaseReady == false` and no
fake is injected, the gate is skipped entirely (today's behaviour).

### 4. Swap the repositories in `dependencies.dart` when signed in — DONE

`buildHistoryRepository()` / `buildFavoritesRepository()` in `lib/app/dependencies.dart`
short-circuit on `firebaseReady` (so `FirebaseAuth.instance` is never read when Firebase is
not ready) and return the cloud repository scoped to the signed-in uid, else the M5.1
`SharedPrefs*` fallback. The app-wide `FavoritesCubit` provider is keyed on the uid (via
`MaterialApp.router`'s `builder`) so it rebinds to the right repository on sign-in/out:

```dart
RunHistoryRepository buildHistoryRepository() {
  final uid = firebaseReady ? FirebaseAuth.instance.currentUser?.uid : null;
  return uid != null
      ? FirestoreRunHistoryRepository(FirebaseFirestore.instance, uid)
      : SharedPrefsRunHistoryRepository(appPrefs);
}

FavoritesRepository buildFavoritesRepository() {
  final uid = firebaseReady ? FirebaseAuth.instance.currentUser?.uid : null;
  return uid != null
      ? FirestoreFavoritesRepository(FirebaseFirestore.instance, uid)
      : SharedPrefsFavoritesRepository(appPrefs);
}
```

The `firebaseReady ? ... : null` short-circuit guarantees `FirebaseAuth.instance` is only
read when Firebase is initialised. Both history and favourites now route through these
builders, so the swap is centralised.

### 5. Console + rules — REMAINING (project owner)

These two actions are not code; they must be done once in the Firebase console / CLI by
the project owner before sign-in and cloud writes work end-to-end:

- **Authentication → Sign-in method → enable Email/Password.** Until this is on, sign-in
  surfaces "Email sign-in is not enabled for this app yet" (the `operation-not-allowed`
  message in `FirebaseAuthRepository`).
- **Deploy the security rules** in `firestore.rules` (at repo root):
  `firebase deploy --only firestore:rules`
  The rules restrict `/users/{userId}/**` to the owning, authenticated user, matching the
  `/users/{uid}/runs/{autoId}` and `/users/{uid}/favorites/{routeKey}` data model the
  Firestore repositories write to. (The Firestore database itself is already created.)

### 6. A sign-out action in the UI — DONE

`HomeScreen` shows a sign-out `IconButton` (`Icons.logout`) in the top-right nav row,
rendered only in Firebase mode (a nullable `context.read<AuthCubit?>()` returns `null` in
local mode, so the button is hidden there). It calls `context.read<AuthCubit>().signOut()`;
the gate's `refreshListenable` then returns the user to `SignInScreen` automatically via
the auth-state stream.

## Verification after going live

- `flutter analyze` clean; `flutter test` green (the mock-based tests are unaffected).
- Sign up, then land on home; record a run or favourite a route, and it appears under
  `/users/{uid}/runs` and `/users/{uid}/favorites` in the Firestore console.
- Sign out, which returns to `SignInScreen`; sign in as a different user, who sees only their own
  data (per-user isolation, enforced by both the path scoping and the rules).

## Known caveats to handle at go-live

- **`serverTimestamp()` + `orderBy('createdAt')` pending-write ordering.**
  `FirestoreRunHistoryRepository.save` writes `createdAt: FieldValue.serverTimestamp()`.
  In the real SDK, a doc read back *immediately* after `save` (before the server write
  resolves) has a local `createdAt == null`, so a just-saved run can momentarily sort to
  the bottom (or out of order) under `orderBy('createdAt', descending: true)` until the
  server round-trip lands. The `fake_cloud_firestore` test resolves it synchronously and
  doesn't exercise this window. If the history list flickers/misorders right after saving,
  either read that list with `GetOptions(source: Source.server)`, or sort client-side with
  a null-last fallback. Not a crash, purely the post-save ordering window.
