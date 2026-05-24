import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/domain/models/app_user.dart';
import 'package:freshloop/features/auth/sign_in_screen.dart';
import 'package:freshloop/services/auth_repository.dart';
import 'package:freshloop/state/auth_cubit.dart';

// Reuse the hand-written fake from the AuthCubit test.
class _FakeAuth implements AuthRepository {
  final _ctrl = StreamController<AppUser?>.broadcast();
  AppUser? _user;
  bool throwOnNext = false;
  int signInCalls = 0;
  @override
  Stream<AppUser?> authStateChanges() => _ctrl.stream;
  @override
  AppUser? get currentUser => _user;
  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
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

Widget _wrap(AuthRepository repo) => MaterialApp(
      home: BlocProvider<AuthCubit>(
        create: (_) => AuthCubit(repo),
        child: const SignInScreen(),
      ),
    );

void main() {
  testWidgets('empty submit shows validation errors and does not call the repo',
      (tester) async {
    final repo = _FakeAuth();
    await tester.pumpWidget(_wrap(repo));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('At least 6 characters'), findsOneWidget);
    expect(repo.signInCalls, 0);
  });

  testWidgets('valid email + password and tapping Sign in signs the user in',
      (tester) async {
    final repo = _FakeAuth();
    await tester.pumpWidget(_wrap(repo));
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'a@b.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret1');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(repo.signInCalls, 1);
    expect(find.text('Enter a valid email'), findsNothing);
    expect(find.text('At least 6 characters'), findsNothing);

    final cubit = tester.element(find.byType(SignInScreen)).read<AuthCubit>();
    expect(cubit.state.status, AuthStatus.signedIn);
    expect(cubit.state.user?.email, 'a@b.com');
  });

  testWidgets('an auth error is announced via a liveRegion Semantics',
      (tester) async {
    final repo = _FakeAuth()..throwOnNext = true;
    await tester.pumpWidget(_wrap(repo));
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'a@b.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret1');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('bad creds'), findsOneWidget);
    // The error text is wrapped so screen readers announce it on appearance.
    final liveRegion = find.ancestor(
      of: find.text('bad creds'),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true,
      ),
    );
    expect(liveRegion, findsOneWidget);
  });

  testWidgets('the toggle switches the CTA label to Create account',
      (tester) async {
    final repo = _FakeAuth();
    await tester.pumpWidget(_wrap(repo));
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create account'), findsNothing);

    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsNothing);
  });
}
