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
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_friendly(e));
    }
  }

  String _friendly(fb.FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That email address is not valid.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Wrong email or password.',
        'email-already-in-use' => 'An account already exists for that email.',
        'weak-password' => 'Please choose a stronger password.',
        'network-request-failed' => 'Network error — check your connection.',
        'too-many-requests' => 'Too many attempts. Please wait and try again.',
        // Email/Password provider not enabled in the Firebase console — the
        // classic first-deploy gotcha; surface it clearly instead of "failed".
        'operation-not-allowed' => 'Email sign-in is not enabled for this app yet.',
        _ => 'Authentication failed. Please try again.',
      };
}
