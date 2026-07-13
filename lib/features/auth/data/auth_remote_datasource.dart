import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../domain/entities/auth_user.dart';

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

    if (response.statusCode != 200 || response.data == null) {
      throw StateError('auth_session_failed_${response.statusCode}');
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
      idToken: idToken,
    );
  }
}
