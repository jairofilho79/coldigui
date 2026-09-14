import 'package:dio/dio.dart';

import '../../features/auth/domain/entities/auth_user.dart';

/// `401` numa request que saiu com `Authorization: Bearer sess_…` significa
/// «o Worker não reconhece mais esta sessão» (revogada ou vencida — spec D8).
/// Avisa o `AuthNotifier` e deixa o 401 seguir para o chamador.
///
/// Não age em rota pública (sem `Authorization`) nem no JWT do Google (só a
/// `POST /api/auth/session` o manda — um 401 ali é «login falhou», não
/// «sessão morreu»). 403 é permissão, não sessão.
///
/// Trata as duas pontas porque os datasources autenticados usam
/// `validateStatus: < 500` — para eles o 401 chega como **resposta**
/// (`onResponse`), não como `DioException` (`onError`).
class AuthUnauthorizedInterceptor extends Interceptor {
  AuthUnauthorizedInterceptor({required this.onUnauthorized});

  final void Function() onUnauthorized;

  static bool _isSessionRequest(RequestOptions options) {
    final auth = options.headers['Authorization'];
    return auth is String && auth.startsWith('Bearer $kSessionTokenPrefix');
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (response.statusCode == 401 &&
        _isSessionRequest(response.requestOptions)) {
      onUnauthorized();
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401 &&
        _isSessionRequest(err.requestOptions)) {
      onUnauthorized();
    }
    handler.next(err);
  }
}
