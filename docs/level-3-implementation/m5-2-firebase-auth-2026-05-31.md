# FreshLoop M5.2 — Auth + cloud sync (Firebase, built credential-free) · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or superpowers:executing-plans. Checkbox (`- [ ]`) steps.

**Goal:** Add email/password **authentication** and a **cloud** implementation of the M5.1 history/favourites repositories (Firestore), behind interfaces, so a signed-in user's data syncs to the cloud.

**Build strategy (important):** This is built **without any real Firebase project or credential** — all Firebase code is unit/widget-tested with **mocks** (`firebase_auth_mocks`, `fake_cloud_firestore`). The running app is **NOT switched to Firebase in this pass**: `main()`, the router, and `dependencies.dart` are left untouched, so the app keeps running on M5.1 local storage and web screenshots keep working. "Going live" (real `firebase_options.dart` + guarded `Firebase.initializeApp` + an `AuthGate` + repo swap + console toggles + rules deploy) is a separate, well-defined final step gated on the user's project — captured in `docs/level-3-implementation/m5-2-going-live.md` (Task 6).

**Two phases:**
- **Phase A — backend-agnostic auth layer** (NO firebase deps): `AppUser`, `AuthRepository` interface, `AuthCubit`, `SignInScreen`. Tested with a hand-written fake repo. *This survives even if the backend later becomes Supabase — only the impl changes.*
- **Phase B — Firebase implementations**: add firebase deps; `FirebaseAuthRepository` + `FirestoreRunHistoryRepository` + `FirestoreFavoritesRepository` (implement the existing `RunHistoryRepository`/`FavoritesRepository` interfaces from M5.1). Tested with `firebase_auth_mocks` + `fake_cloud_firestore`.

**SSOT:** [system design](../level-2-architecture/running-route-generator-2026-05-30.md) §8; builds on M5.1 ([plan](m5-1-history-favorites-2026-05-31.md)) — reuses `RunRecord`/`ScoredRoute` `toJson`/`fromJson` and the `RunHistoryRepository`/`FavoritesRepository` interfaces. Firestore data model matches the published security rules: `/users/{uid}/runs/{autoId}` and `/users/{uid}/favorites/{routeKey}`.

**Notes:** Flutter at `$HOME/flutter/bin/flutter`. English only; Conventional Commits; **no AI/tooling attribution**. **`flutter test` + `flutter analyze` green before every commit.** `lib/domain` stays Flutter-free. Do NOT create `firebase_options.dart` (it's gitignored and we have no real values yet) and do NOT call `Firebase.initializeApp` anywhere in this pass.

---

## Task 0: Dependency resolution gate (do FIRST, report if it fails)

**Files:** `pubspec.yaml`

- [ ] **Step 1:** `flutter pub add firebase_core firebase_auth cloud_firestore`
- [ ] **Step 2:** `flutter pub add dev:fake_cloud_firestore dev:firebase_auth_mocks`
- [ ] **Step 3:** `flutter pub get` then `flutter analyze` — confirm the project still compiles with the new deps and **the existing 100 tests still pass** (`flutter test`). The plugins must not break host-VM tests (they don't touch native in `flutter test`).
- [ ] **Step 4:** If `fake_cloud_firestore` / `firebase_auth_mocks` cannot co-resolve with the latest firebase plugins, pin the firebase plugins down to the newest versions the mocks support (check the mocks' pubspec constraints), re-resolve, and **note the chosen versions in the commit message**. If it still cannot resolve, STOP and report the conflict — do not hack around it.
- [ ] **Step 5:** Commit: `git commit -am "build: add firebase + mock test dependencies"`

> Phase A (Tasks 1–3) has **no** dependency on Task 0 succeeding — if Task 0's mocks won't resolve, still complete Phase A (it uses only a hand-written fake), and report Phase B blocked.

---

## Phase A — backend-agnostic auth layer

## Task 1: `AppUser` + `AuthRepository` interface

**Files:** create `lib/domain/models/app_user.dart`, `lib/services/auth_repository.dart`

- [ ] **Step 1:** `lib/domain/models/app_user.dart` (pure Dart, Flutter-free):
```dart
/// The minimal user identity the app needs — decoupled from any auth backend.
class AppUser {
  final String uid;
  final String? email;
  const AppUser({required this.uid, this.email});

  @override
  bool operator ==(Object other) =>
      other is AppUser && other.uid == uid && other.email == email;
  @override
  int get hashCode => Object.hash(uid, email);
}
```
- [ ] **Step 2:** `lib/services/auth_repository.dart`:
```dart
import '../domain/models/app_user.dart';

/// Auth backend seam. Firebase is the M5.2 impl; could be swapped (e.g. Supabase)
/// without touching the cubit or UI.
abstract class AuthRepository {
  /// Emits the current user (or null when signed out) and on every change.
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;
  Future<void> signIn({required String email, required String password});
  Future<void> signUp({required String email, required String password});
  Future<void> signOut();
}

/// A user-facing auth failure with a friendly message.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
```
- [ ] **Step 3:** `flutter analyze`. Commit: `git commit -am "feat: add AppUser + AuthRepository interface"`

## Task 2: `AuthCubit`

**Files:** create `lib/state/auth_cubit.dart`, `test/state/auth_cubit_test.dart`

- [ ] **Step 1: Failing test** — `test/state/auth_cubit_test.dart` with a hand-written fake repo:
```dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/domain/models/app_user.dart';
import 'package:freshloop/services/auth_repository.dart';
import 'package:freshloop/state/auth_cubit.dart';

class _FakeAuth implements AuthRepository {
  final _ctrl = StreamController<AppUser?>.broadcast();
  AppUser? _user;
  bool throwOnNext = false;
  @override
  Stream<AppUser?> authStateChanges() => _ctrl.stream;
  @override
  AppUser? get currentUser => _user;
  @override
  Future<void> signIn({required String email, required String password}) async {
    if (throwOnNext) throw AuthException('bad creds');
    _user = AppUser(uid: 'u1', email: email);
    _ctrl.add(_user);
  }
  @override
  Future<void> signUp({required String email, required String password}) async {
    _user = AppUser(uid: 'u2', email: email);
    _ctrl.add(_user);
  }
  @override
  Future<void> signOut() async {
    _user = null;
    _ctrl.add(null);
  }
}

void main() {
  test('starts unknown then resolves to signed-out', () async {
    final repo = _FakeAuth();
    final cubit = AuthCubit(repo);
    expect(cubit.state.status, AuthStatus.unknown);
    repo._ctrl.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.status, AuthStatus.signedOut);
    await cubit.close();
  });

  test('signIn transitions to signedIn and clears error', () async {
    final repo = _FakeAuth();
    final cubit = AuthCubit(repo);
    await cubit.signIn(email: 'a@b.com', password: 'pw');
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.status, AuthStatus.signedIn);
    expect(cubit.state.user?.email, 'a@b.com');
    expect(cubit.state.submitting, isFalse);
    expect(cubit.state.error, isNull);
    await cubit.close();
  });

  test('signIn failure surfaces an error and is not submitting', () async {
    final repo = _FakeAuth()..throwOnNext = true;
    final cubit = AuthCubit(repo);
    await cubit.signIn(email: 'a@b.com', password: 'pw');
    expect(cubit.state.error, 'bad creds');
    expect(cubit.state.submitting, isFalse);
    expect(cubit.state.status, isNot(AuthStatus.signedIn));
    await cubit.close();
  });
}
```
- [ ] **Step 2: Implement** `lib/state/auth_cubit.dart`:
```dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/models/app_user.dart';
import '../services/auth_repository.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final bool submitting;
  final String? error;
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.submitting = false,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, AppUser? user, bool? submitting, String? error, bool clearError = false}) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        submitting: submitting ?? this.submitting,
        error: clearError ? null : (error ?? this.error),
      );
}

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repo;
  late final StreamSubscription<AppUser?> _sub;

  AuthCubit(this._repo) : super(const AuthState()) {
    _sub = _repo.authStateChanges().listen((user) {
      emit(state.copyWith(
        status: user == null ? AuthStatus.signedOut : AuthStatus.signedIn,
        user: user,
        clearError: true,
      ));
    });
  }

  Future<void> signIn({required String email, required String password}) =>
      _run(() => _repo.signIn(email: email, password: password));
  Future<void> signUp({required String email, required String password}) =>
      _run(() => _repo.signUp(email: email, password: password));
  Future<void> signOut() => _repo.signOut();

  Future<void> _run(Future<void> Function() action) async {
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      await action();
      emit(state.copyWith(submitting: false));
    } on AuthException catch (e) {
      emit(state.copyWith(submitting: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(submitting: false, error: 'Something went wrong. Please try again.'));
    }
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
```
- [ ] **Step 3: Run → PASS (3).** `flutter analyze`. Commit: `git commit -am "feat: add AuthCubit (auth state + sign-in/up/out)"`

## Task 3: `SignInScreen`

**Files:** create `lib/features/auth/sign_in_screen.dart`, `test/features/auth/sign_in_screen_test.dart`

- [ ] **Step 1: Implement** `lib/features/auth/sign_in_screen.dart` — email + password, a sign-in / create-account toggle, a primary CTA (amber accent, the reserved CTA colour), loading + error states. Reads `AuthCubit` via `context`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/theme.dart';
import '../../state/auth_cubit.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSignUp = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit(AuthCubit cubit) {
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim();
    final pw = _password.text;
    _isSignUp ? cubit.signUp(email: email, password: pw) : cubit.signIn(email: email, password: pw);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final state = context.watch<AuthCubit>().state;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('FreshLoop', style: t.textTheme.displaySmall, textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(_isSignUp ? 'Create your account' : 'Welcome back',
                      style: t.textTheme.bodyLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: 12),
                    Text(state.error!, style: TextStyle(color: t.colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                    onPressed: state.submitting ? null : () => _submit(context.read<AuthCubit>()),
                    child: state.submitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isSignUp ? 'Create account' : 'Sign in'),
                  ),
                  TextButton(
                    onPressed: state.submitting ? null : () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(_isSignUp ? 'Have an account? Sign in' : "New here? Create an account"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```
- [ ] **Step 2: Widget test** — `test/features/auth/sign_in_screen_test.dart` (provide a fake `AuthCubit` via a fake repo, reuse the `_FakeAuth` pattern from Task 2 — copy it in):
```dart
// Pump SignInScreen wrapped in BlocProvider<AuthCubit>(create: (_) => AuthCubit(_FakeAuth())).
// Assert: validation blocks empty submit; entering a valid email+password and tapping
// 'Sign in' calls the repo (state goes signedIn); the toggle switches the CTA label to
// 'Create account'.
```
Write concrete assertions: `find.text('Sign in')`, enter text via `tester.enterText`, tap, `pumpAndSettle`, assert no validator errors / CTA label toggles.
- [ ] **Step 3: Run → PASS.** `flutter analyze`. Commit: `git commit -am "feat: add email/password sign-in screen"`

---

## Phase B — Firebase implementations (mock-tested)

## Task 4: `FirebaseAuthRepository`

**Files:** create `lib/services/firebase_auth_repository.dart`, `test/services/firebase_auth_repository_test.dart`

- [ ] **Step 1: Implement** `lib/services/firebase_auth_repository.dart`:
```dart
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../domain/models/app_user.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _auth;
  FirebaseAuthRepository(this._auth);

  AppUser? _map(fb.User? u) => u == null ? null : AppUser(uid: u.uid, email: u.email);

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_map);
  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_friendly(e));
    }
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_friendly(e));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  String _friendly(fb.FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That email address is not valid.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Wrong email or password.',
        'email-already-in-use' => 'An account already exists for that email.',
        'weak-password' => 'Please choose a stronger password.',
        'network-request-failed' => 'Network error — check your connection.',
        _ => 'Authentication failed. Please try again.',
      };
}
```
- [ ] **Step 2: Test with `firebase_auth_mocks`** — `test/services/firebase_auth_repository_test.dart`:
```dart
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/services/auth_repository.dart';
import 'package:freshloop/services/firebase_auth_repository.dart';

void main() {
  test('signUp creates a user and authStateChanges emits it', () async {
    final mock = MockFirebaseAuth();
    final repo = FirebaseAuthRepository(mock);
    final emissions = <String?>[];
    final sub = repo.authStateChanges().listen((u) => emissions.add(u?.email));
    await repo.signUp(email: 'a@b.com', password: 'secret1');
    await Future<void>.delayed(Duration.zero);
    expect(repo.currentUser?.email, 'a@b.com');
    expect(emissions, contains('a@b.com'));
    await sub.cancel();
  });

  test('signOut clears the current user', () async {
    final mock = MockFirebaseAuth(signedIn: true);
    final repo = FirebaseAuthRepository(mock);
    expect(repo.currentUser, isNotNull);
    await repo.signOut();
    expect(repo.currentUser, isNull);
  });
}
```
> If `MockFirebaseAuth`'s API differs in the resolved version (e.g. `signInWithEmailAndPassword` not stubbed), adapt the test to the version's supported surface; keep the assertions on `currentUser` / emissions.
- [ ] **Step 3: Run → PASS.** `flutter analyze`. Commit: `git commit -am "feat: add FirebaseAuthRepository (mock-tested)"`

## Task 5: Firestore repositories

**Files:** create `lib/services/firestore_run_history_repository.dart`, `lib/services/firestore_favorites_repository.dart`, `test/services/firestore_repositories_test.dart`

- [ ] **Step 1: Implement** `lib/services/firestore_run_history_repository.dart`:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/run_record.dart';
import 'run_history_repository.dart';

/// Cloud-backed run history under /users/{uid}/runs (matches the security rules).
class FirestoreRunHistoryRepository implements RunHistoryRepository {
  final FirebaseFirestore _db;
  final String uid;
  FirestoreRunHistoryRepository(this._db, this.uid);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(uid).collection('runs');

  @override
  Future<void> save(RunRecord record) async {
    await _col.add({...record.toJson(), 'createdAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<List<RunRecord>> all() async {
    final snap = await _col.orderBy('createdAt', descending: true).get();
    final out = <RunRecord>[];
    for (final d in snap.docs) {
      try {
        out.add(RunRecord.fromJson(d.data()));
      } catch (_) {/* skip a malformed doc */}
    }
    return out;
  }
}
```
And `lib/services/firestore_favorites_repository.dart`:
```dart
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
```
- [ ] **Step 2: Test with `fake_cloud_firestore`** — `test/services/firestore_repositories_test.dart`:
```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/routing/route_geometry.dart';
import 'package:freshloop/domain/models/axis_score.dart';
import 'package:freshloop/domain/models/run_record.dart';
import 'package:freshloop/domain/models/score_breakdown.dart';
import 'package:freshloop/domain/models/scored_route.dart';
import 'package:freshloop/services/firestore_favorites_repository.dart';
import 'package:freshloop/services/firestore_run_history_repository.dart';

ScoredRoute _route(int seed) => ScoredRoute(
      seed: seed,
      geometry: RouteGeometry(points: const [RoutePoint(lat: 45, lng: 9)], distanceM: 5000.0 + seed, ascentM: 40),
      score: ScoreBreakdown(air: AxisScore(80), hills: AxisScore(60), scenery: AxisScore(40), total: 60, explanation: 'x'),
    );

void main() {
  test('run history saves and lists under the user subtree', () async {
    final db = FakeFirebaseFirestore();
    final repo = FirestoreRunHistoryRepository(db, 'u1');
    await repo.save(const RunRecord(points: [], distanceM: 1000, durationS: 300));
    await repo.save(const RunRecord(points: [], distanceM: 2000, durationS: 600));
    final all = await repo.all();
    expect(all.length, 2);
    // isolation: another user sees nothing
    expect(await FirestoreRunHistoryRepository(db, 'u2').all(), isEmpty);
  });

  test('favourites add/list/isFavorite/remove by routeKey', () async {
    final db = FakeFirebaseFirestore();
    final repo = FirestoreFavoritesRepository(db, 'u1');
    final a = _route(1);
    await repo.add(a);
    await repo.add(a); // idempotent (same doc id)
    expect((await repo.all()).length, 1);
    expect(await repo.isFavorite(a.routeKey), isTrue);
    await repo.remove(a.routeKey);
    expect(await repo.all(), isEmpty);
    expect(await repo.isFavorite(a.routeKey), isFalse);
  });
}
```
> `fake_cloud_firestore` supports `FieldValue.serverTimestamp()` + `orderBy`. If a resolved-version quirk makes `orderBy('createdAt')` drop docs whose server timestamp hasn't resolved, switch `save` to write `'createdAt': Timestamp.now()` (still fine for the real app) and keep the test.
- [ ] **Step 3: Run → PASS.** `flutter analyze`. Commit: `git commit -am "feat: add Firestore history + favourites repositories (mock-tested)"`

---

## Task 6: "Going live" doc (the remaining gated step)

**Files:** create `docs/level-3-implementation/m5-2-going-live.md`

- [ ] Write a short doc capturing EXACTLY what's left to connect the real backend (so it's unambiguous later). Include:
  1. `flutterfire configure` (or paste config) → generates gitignored `lib/firebase_options.dart`.
  2. `main()` becomes async: `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` inside a `try/catch`; on success set a `firebaseReady` flag.
  3. Add an `AuthGate` at the router root: `unknown`→splash, `signedOut`→`SignInScreen`, `signedIn`→current home.
  4. `dependencies.dart`: when signed in, build `FirebaseAuthRepository` + `Firestore*Repository(db, uid)`; otherwise keep the M5.1 `SharedPrefs*` repos (graceful fallback so the app still runs with no project).
  5. Console: enable Email/Password; Firestore database already created; deploy the rules in `firestore.rules` (`firebase deploy --only firestore:rules`).
  6. A sign-out action somewhere in the UI (e.g. a profile/menu entry).
- [ ] Also create `firestore.rules` at repo root with the published rules (the `/users/{userId}/{document=**}` owner rule) + a `firebase.json` pointing `firestore.rules` at it, so a later `firebase deploy --only firestore:rules` works. Commit: `git commit -m "docs: add M5.2 going-live steps + firestore.rules"`

---

## Task 7: Final verification

- [ ] `flutter test` → all green (100 prior + Phase A: auth-cubit 3 + sign-in widget tests + Phase B: firebase-auth 2 + firestore 2 ≈ **108+**).
- [ ] `flutter analyze` → clean.
- [ ] **App still runs on local storage:** `main.dart`, `router.dart`, `dependencies.dart` are unchanged except deps; no `Firebase.initializeApp` call exists yet; no `firebase_options.dart` committed.
- [ ] `git status` clean; `lib/domain` Flutter-free; no secrets/real config committed.

---

## Self-Review (author)

**Spec coverage:** auth (email/password) → Tasks 1–4; cloud history/favourites → Task 5 (same interfaces as M5.1, scoped `/users/{uid}/...` to match the rules); UI → Task 3. Backend seam preserved (Phase A is impl-agnostic). Deferred & documented: real-project activation (Task 6).

**Risk register:** (1) firebase/mocks dependency co-resolution — gated in Task 0, Phase A independent. (2) `firebase_auth_mocks`/`fake_cloud_firestore` API drift — adaptation notes inline. (3) Adding firebase plugins must not break `flutter test`/`analyze` (host VM only) — verified in Task 0 Step 3. (4) App must keep running with no real project — guaranteed by NOT wiring init/router/deps this pass.

**Type consistency:** `AuthRepository`/`AppUser` consumed by `AuthCubit` + `SignInScreen`; `FirebaseAuthRepository` implements `AuthRepository`; `Firestore*Repository` implement the M5.1 `RunHistoryRepository`/`FavoritesRepository` and reuse `RunRecord`/`ScoredRoute` `toJson`/`fromJson` + `routeKey`. No change to existing screens.
