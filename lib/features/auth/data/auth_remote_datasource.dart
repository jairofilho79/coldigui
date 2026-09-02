import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../domain/entities/auth_user.dart';

/// Erro de criação de username com código estável da API.
class UsernameException implements Exception {
  UsernameException(this.code);

  final String code;

  @override
  String toString() => 'UsernameException($code)';
}

/// Worker recusou o `idToken` (401/403) — sessão inválida, deve deslogar.
///
/// Distinto de falha de rede/timeout ou 5xx, que preservam a sessão local
/// (ver [AuthNotifier.build]).
class AuthUnauthorizedException implements Exception {
  AuthUnauthorizedException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'AuthUnauthorizedException($statusCode)';
}

/// `POST /api/auth/session` — valida id_token e UPSERT em D1.
class AuthRemoteDatasource {
  AuthRemoteDatasource(this._dio);

  final Dio _dio;

  Future<AuthUser> establishSession(String idToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.authSession,
      options: Options(
        headers: {'Authorization': 'Bearer $idToken'},
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    final statusCode = response.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      throw AuthUnauthorizedException(statusCode!);
    }

    if (statusCode != 200 || response.data == null) {
      throw StateError('auth_session_failed_$statusCode');
    }

    final data = response.data!;
    final sub = data['googleSub'];
    if (sub is! String || sub.isEmpty) {
      throw StateError('auth_session_missing_sub');
    }

    return AuthUser(
      googleSub: sub,
      email: data['email'] as String?,
      name: data['name'] as String?,
      pictureUrl: data['pictureUrl'] as String?,
      username: data['username'] as String?,
      idToken: idToken,
    );
  }

  /// `PUT /api/auth/username` — define handle único (uma vez).
  Future<String> setUsername({
    required String idToken,
    required String username,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      ApiEndpoints.authUsername,
      data: {'username': username},
      options: Options(
        headers: {'Authorization': 'Bearer $idToken'},
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    final status = response.statusCode ?? 0;
    final data = response.data;
    if (status == 200 && data != null) {
      final value = data['username'];
      if (value is String && value.isNotEmpty) return value;
      throw UsernameException('invalid response');
    }

    final error = data?['error'];
    throw UsernameException(error is String ? error : 'request_failed_$status');
  }
}
