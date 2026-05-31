import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freshloop/app/app.dart';
import 'package:freshloop/app/dependencies.dart';
import 'package:freshloop/domain/models/app_user.dart';
import 'package:freshloop/features/auth/splash_screen.dart';
import 'package:freshloop/services/auth_repository.dart';

/// An auth repository whose stream never emits, so the AuthCubit stays in the
/// initial `AuthStatus.unknown` state — exercising the loading splash.
class _PendingAuth implements AuthRepository {
  final _ctrl = StreamController<AppUser?>.broadcast();
  @override
  Stream<AppUser?> authStateChanges() => _ctrl.stream;
  @override
  AppUser? get currentUser => null;
  @override
  Future<void> signIn({required String email, required String password}) async {}
  @override
  Future<void> signUp({required String email, required String password}) async {}
  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('SplashScreen shows the brand and a progress indicator',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    expect(find.text('FreshLoop'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Firebase mode shows the splash while auth status is unknown',
      (tester) async {
    firebaseReady = false; // never touch real Firebase
    SharedPreferences.setMockInitialValues({});
    appPrefs = await SharedPreferences.getInstance();

    // Injecting an authRepository puts the app in Firebase mode (auth gate),
    // and the pending stream keeps the AuthCubit in `unknown`.
    await tester.pumpWidget(FreshLoopApp(authRepository: _PendingAuth()));
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    // The sign-in screen must not flash before auth resolves.
    expect(find.text('Welcome back'), findsNothing);
  });
}
