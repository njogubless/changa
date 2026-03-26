import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../errors/failures.dart';

class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage;

  // Prevents multiple simultaneous refresh calls
  bool _isRefreshing = false;
  final List<Function> _pendingRequests = [];

  ApiClient(this._storage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    _dio.interceptors.add(_AuthInterceptor(this, _storage));
  }

  Dio get dio => _dio;

  Future<Response> get(String path, {Map<String, dynamic>? params}) async {
    try {
      return await _dio.get(path, queryParameters: params);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<String?> getAccessToken() =>
      _storage.read(key: AppConstants.accessTokenKey);

  Future<String?> getRefreshToken() =>
      _storage.read(key: AppConstants.refreshTokenKey);

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: access);
    await _storage.write(key: AppConstants.refreshTokenKey, value: refresh);
  }

  Future<void> clearTokens() async {
    await _storage.deleteAll();
  }

  Failure _mapError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const NetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        final data = e.response?.data;
        final message = _extractMessage(data);
        if (status == 401) return AuthFailure(message);
        if (status == 404) return NotFoundFailure(message);
        if (status == 422) return ValidationFailure(message);
        return ServerFailure(message, statusCode: status);
      default:
        return const UnexpectedFailure();
    }
  }

  String _extractMessage(dynamic data) {
    if (data is Map) {
      return data['detail']?.toString() ??
          data['message']?.toString() ??
          'Something went wrong';
    }
    return 'Something went wrong';
  }
}

class _AuthInterceptor extends Interceptor {
  final ApiClient _client;
  final FlutterSecureStorage _storage;

  _AuthInterceptor(this._client, this._storage);

  static const _publicPaths = [
    ApiConstants.register,
    ApiConstants.login,
    ApiConstants.refresh,
  ];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final isPublic = _publicPaths.any((p) => options.path.endsWith(p));
    if (!isPublic) {
      final token = await _storage.read(key: AppConstants.accessTokenKey);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isPublic = _publicPaths.any(
      (p) => err.requestOptions.path.endsWith(p),
    );
    if (err.response?.statusCode != 401 || isPublic) {
      return handler.next(err);
    }

    try {
      final refreshToken = await _storage.read(
        key: AppConstants.refreshTokenKey,
      );
      if (refreshToken == null) return handler.next(err);

      final refreshResponse = await _client.dio.post(
        ApiConstants.refresh,
        data: {'refresh_token': refreshToken},
        options: Options(headers: {}),
      );

      final newAccess = refreshResponse.data['access_token'] as String;
      final newRefresh = refreshResponse.data['refresh_token'] as String;

      await _client.saveTokens(access: newAccess, refresh: newRefresh);

      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newAccess';
      final retryResponse = await _client.dio.fetch(retryOptions);
      handler.resolve(retryResponse);
    } on DioException {
      await _client.clearTokens();
      handler.next(err);
    }
  }
}
