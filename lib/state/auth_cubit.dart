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
      if (isClosed) return;
      // The auth stream is authoritative about status + user together, so build
      // the state directly: this guarantees `user` is cleared to null on sign-out
      // (a copyWith with `user ?? this.user` could never null it).
      emit(AuthState(
        status: user == null ? AuthStatus.signedOut : AuthStatus.signedIn,
        user: user,
        submitting: state.submitting,
      ));
    });
  }

  Future<void> signIn({required String email, required String password}) =>
      _run(() => _repo.signIn(email: email, password: password));
  Future<void> signUp({required String email, required String password}) =>
      _run(() => _repo.signUp(email: email, password: password));
  Future<void> signOut() => _run(() => _repo.signOut());

  Future<void> _run(Future<void> Function() action) async {
    if (isClosed) return;
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      await action();
      if (isClosed) return;
      emit(state.copyWith(submitting: false));
    } on AuthException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(submitting: false, error: e.message));
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(submitting: false, error: 'Something went wrong. Please try again.'));
    }
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
