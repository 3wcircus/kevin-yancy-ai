import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';

// ---------------------------------------------------------------------------
// Auth State Providers
// ---------------------------------------------------------------------------

/// Stream of the current Firebase [User] (null when signed out).
final authStateStreamProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Synchronous snapshot of current auth state.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// The current signed-in user, or null.
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

/// Whether the current user is authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

// ---------------------------------------------------------------------------
// Role Provider
// Reads the custom claim from the ID token result.
// ---------------------------------------------------------------------------
final userRoleProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  // Force-refresh to get latest custom claims
  final idTokenResult = await user.getIdTokenResult(false);
  final claims = idTokenResult.claims;
  return claims?['role'] as String?;
});

/// Convenience bool providers for role checks.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final role = await ref.watch(userRoleProvider.future);
  return role == 'admin';
});

final isAdminOrDelegateProvider = FutureProvider<bool>((ref) async {
  final role = await ref.watch(userRoleProvider.future);
  return role == 'admin' || role == 'delegate';
});

// ---------------------------------------------------------------------------
// Auth Service (sign-in / sign-out actions)
// ---------------------------------------------------------------------------
class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(FirebaseAuth.instance);
});

// ---------------------------------------------------------------------------
// Login State Notifier
// ---------------------------------------------------------------------------
enum LoginStatus { idle, loading, success, error }

class LoginState {
  const LoginState({
    this.status = LoginStatus.idle,
    this.errorMessage,
  });

  final LoginStatus status;
  final String? errorMessage;

  LoginState copyWith({LoginStatus? status, String? errorMessage}) {
    return LoginState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class LoginNotifier extends StateNotifier<LoginState> {
  LoginNotifier(this._authService) : super(const LoginState());

  final AuthService _authService;

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(status: LoginStatus.loading, errorMessage: null);
    try {
      await _authService.signInWithEmail(email.trim(), password);
      // Mark any pending invite as accepted (fire-and-forget, don't block login)
      unawaited(FirebaseFunctions.instance
          .httpsCallable(FunctionNames.acceptInvite)
          .call()
          .then((_) {}, onError: (_) {}));
      state = state.copyWith(status: LoginStatus.success);
    } on FirebaseAuthException catch (e) {
      final message = _mapFirebaseError(e.code);
      state = state.copyWith(status: LoginStatus.error, errorMessage: message);
    } catch (e) {
      state = state.copyWith(
        status: LoginStatus.error,
        errorMessage: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = const LoginState();
  }

  void clearError() {
    state = state.copyWith(status: LoginStatus.idle, errorMessage: null);
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return 'Sign-in failed. Please check your credentials.';
    }
  }
}

final loginProvider = StateNotifierProvider<LoginNotifier, LoginState>((ref) {
  return LoginNotifier(ref.watch(authServiceProvider));
});
