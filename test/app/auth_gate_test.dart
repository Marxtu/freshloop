import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freshloop/app/app.dart';
import 'package:freshloop/app/dependencies.dart';
import 'package:freshloop/domain/models/app_user.dart';
import 'package:freshloop/features/auth/sign_in_screen.dart';
import 'package:freshloop/features/common/route_map.dart';
import 'package:freshloop/services/auth_repository.dart';

/// Fake auth that drives the gate without a real Firebase app. [seed] is the
/// initial auth state the stream emits on subscription (null = signed out).
class _FakeAuth implements AuthRepository {
  final _ctrl = StreamController<AppUser?>.broadcast();
  AppUser? _user;
  final AppUser? _seed;
  _FakeAuth({AppUser? seed}) : _user = seed, _seed = seed;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _seed; // resolves the cubit out of `unknown` immediately
    yield* _ctrl.stream;
  }

  @override
  AppUser? get currentUser => _user;
  @override
  Future<void> signIn({required String email, required String password}) async {
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

/// Pumps a few discrete frames to flush the async auth stream + the router's
/// redirect, without `pumpAndSettle` (which would hang on the map's tile fetch).
Future<void> _flush(WidgetTester tester) async {
  // Enough wall-clock to flush the async auth stream AND complete a go_router
  // page transition (~300ms), so the outgoing route is fully gone.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    appPrefs = await SharedPreferences.getInstance(); // late final: set once per file
  });

  setUp(() {
    firebaseReady = false; // never initialize Firebase; the injected fake drives the gate
  });

  testWidgets('signed-out user is gated to the sign-in screen', (tester) async {
    await tester.pumpWidget(FreshLoopApp(authRepository: _FakeAuth()));
    await _flush(tester);
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(RouteMap), findsNothing);
  });

  testWidgets('signed-in user lands on the home map, not the sign-in screen', (tester) async {
    final repo = _FakeAuth(seed: const AppUser(uid: 'u1', email: 'a@b.com'));
    await tester.pumpWidget(FreshLoopApp(authRepository: repo));
    await _flush(tester);
    expect(find.byType(RouteMap), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
  });

  testWidgets('signing in moves the user from the gate to the home map', (tester) async {
    final repo = _FakeAuth();
    await tester.pumpWidget(FreshLoopApp(authRepository: repo));
    await _flush(tester);
    expect(find.byType(SignInScreen), findsOneWidget);

    await repo.signIn(email: 'a@b.com', password: 'secret1');
    await _flush(tester); // auth event → refreshListenable → redirect → navigation
    expect(find.byType(RouteMap), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
  });
}
