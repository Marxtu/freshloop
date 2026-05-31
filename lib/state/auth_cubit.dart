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
