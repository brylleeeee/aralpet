import 'package:dio/dio.dart';
import 'env.dart';
import 'token_storage.dart';

/// A readable error from the API, e.g. "The email has already been taken."
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.fieldErrors = const {}});

  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors; // from Laravel's 422 "errors"

  @override
  String toString() => message;
}

class ApiService {
  ApiService(this._storage, {this.onUnauthorized})
      : _dio = Dio(BaseOptions(
          baseUrl: Env.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Accept': 'application/json'},
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      // Attach the token to every request.
      onRequest: (options, handler) async {
        final token = await _storage.readToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      // If the server rejects the token, sign the user out.
      onError: (error, handler) async {
        final isAuthCall = error.requestOptions.path.startsWith('/auth/');
        if (error.response?.statusCode == 401 && !isAuthCall) {
          await _storage.clear();
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));
  }

  final Dio _dio;
  final TokenStorage _storage;
  final void Function()? onUnauthorized;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? data}) =>
      _send(() => _dio.post(path, data: data));

  Future<dynamic> put(String path, {Object? data}) =>
      _send(() => _dio.put(path, data: data));

  Future<dynamic> patch(String path, {Object? data}) =>
      _send(() => _dio.patch(path, data: data));

  Future<dynamic> delete(String path) => _send(() => _dio.delete(path));

  Future<dynamic> _send(Future<Response> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  ApiException _toApiException(DioException e) {
    final response = e.response;
    if (response == null) {
      return ApiException(
          'Cannot reach the server. Check that the API is running.');
    }

    final status = response.statusCode;
    final body = response.data;
    var message = 'Something went wrong (error $status).';
    final fieldErrors = <String, String>{};

    if (body is Map) {
      if (body['message'] is String) message = body['message'] as String;
      final errors = body['errors'];
      if (errors is Map) {
        errors.forEach((key, value) {
          if (value is List && value.isNotEmpty) {
            fieldErrors[key.toString()] = value.first.toString();
          }
        });
        if (fieldErrors.isNotEmpty) message = fieldErrors.values.first;
      }
    }
    if (status == 429) {
      message = 'Too many attempts. Please wait a minute and try again.';
    }
    return ApiException(message, statusCode: status, fieldErrors: fieldErrors);
  }
}