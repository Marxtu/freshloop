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
