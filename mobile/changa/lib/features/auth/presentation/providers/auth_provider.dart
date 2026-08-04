import 'package:changa/core/constants/app_constants.dart';
import 'package:changa/core/errors/failures.dart';
import 'package:changa/core/network/api_client.dart';
import 'package:changa/features/auth/data/models/auth_models.dart';
import 'package:changa/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(secureStorageProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  ),
);

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final UserModel user;
  const AuthAuthenticated(this.user);
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AuthInitial()) {
    _checkSession();
  }

  Future<void> _checkSession() async {
    final isLoggedIn = await _repo.isLoggedIn();
    if (!isLoggedIn) {
      state = const AuthUnauthenticated();
      return;
    }
    final user = await _repo.getMe();
    if (user != null) {
      state = AuthAuthenticated(user);
    } else {
      state = const AuthUnauthenticated();
    }
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required bool termsAccepted,
  }) async {
    state = const AuthLoading();
    try {
      final tokens = await _repo.register(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
        termsAccepted: termsAccepted,
      );
      // Persist onboarding flag so it's never shown again after registration.
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setBool(AppConstants.onboardingDoneKey, true),
      );
      state = AuthAuthenticated(tokens.user);
    } on Failure catch (e) {
      state = AuthError(e.message);
    } catch (e) {
      state = AuthError(failureMessage(e));
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AuthLoading();
    try {
      final tokens = await _repo.login(email: email, password: password);
      state = AuthAuthenticated(tokens.user);
    } on Failure catch (e) {
      state = AuthError(e.message);
    } catch (e) {
      state = AuthError(failureMessage(e));
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthUnauthenticated();
  }

  void clearError() {
    if (state is AuthError) state = const AuthUnauthenticated();
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

final currentUserProvider = Provider<UserModel?>((ref) {
  final state = ref.watch(authNotifierProvider);
  return state is AuthAuthenticated ? state.user : null;
});
