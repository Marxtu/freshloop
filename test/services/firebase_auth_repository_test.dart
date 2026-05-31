import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
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
