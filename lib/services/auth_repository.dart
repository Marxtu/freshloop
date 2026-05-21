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
