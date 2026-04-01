import 'package:changa/core/constants/api_constants.dart';
import 'package:changa/core/constants/app_constants.dart';
import 'package:changa/core/network/api_client.dart';
import 'package:changa/features/auth/data/models/auth_models.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class AuthRepository {
  final ApiClient _api;
  final FlutterSecureStorage _storage;

  AuthRepository(this._api, this._storage);

  Future<AuthTokens> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await _api.post(ApiConstants.register, data: {
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'password': password,
    });
    final tokens = AuthTokens.fromJson(response.data);
    await _api.saveTokens(
      access: tokens.accessToken,
      refresh: tokens.refreshToken,
    );
    return tokens;
  }

  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post(ApiConstants.login, data: {
      'email': email,
      'password': password,
    });
    final tokens = AuthTokens.fromJson(response.data);
    await _api.saveTokens(
      access: tokens.accessToken,
      refresh: tokens.refreshToken,
    );
    return tokens;
  }

  Future<void> logout() async {
    try {
      final refresh = await _storage.read(key: AppConstants.refreshTokenKey);
      if (refresh != null) {
        await _api.post(ApiConstants.logout, data: {'refresh_token': refresh});
      }
    } finally {
      await _api.clearTokens();
    }
  }

  Future<UserModel?> getMe() async {
    try {
      final response = await _api.get(ApiConstants.me);
      return UserModel.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await _api.getAccessToken();
    return token != null;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post(ApiConstants.changePassword, data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }
}
