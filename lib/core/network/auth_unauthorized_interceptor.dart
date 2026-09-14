import 'package:dio/dio.dart';

import '../../features/auth/domain/entities/auth_user.dart';

/// `401` numa request que saiu com `Authorization: Bearer sess_…` significa
/// «o Worker não reconhece mais esta sessão» (revogada ou vencida — spec D8).
/// Avisa o `AuthNotifier` com o token recusado e deixa o 401 seguir para o
/// chamador — é o `AuthNotifier` quem decide, comparando com a sessão
/// corrente, se esse 401 ainda é relevante (um 401 atrasado de uma sessão já
/// trocada não pode derrubar a nova).
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

  final void Function(String rejectedToken) onUnauthorized;

  static String? _sessionToken(RequestOptions options) {
    final auth = options.headers['Authorization'];
    if (auth is! String || !auth.startsWith('Bearer $kSessionTokenPrefix')) {
      return null;
    }
    return auth.substring('Bearer '.length);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final token = _sessionToken(response.requestOptions);
    if (response.statusCode == 401 && token != null) {
      onUnauthorized(token);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final token = _sessionToken(err.requestOptions);
    if (err.response?.statusCode == 401 && token != null) {
      onUnauthorized(token);
    }
    handler.next(err);
  }
}
