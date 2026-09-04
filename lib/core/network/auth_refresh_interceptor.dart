import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Renova o `id_token` em cima de um 401 e repete a request **uma** vez.
///
/// Só age em request que já mandou `Authorization`: 401 em rota pública é
/// resposta legítima. 403 não entra — é permissão, não token vencido.
///
/// Se o refresh falhar, o 401 original volta ao chamador (quem marca a sessão
/// como expirada é o próprio refresh). Se a repetição levar 401 de novo, o
/// token novo também não serve: aí sim [markSessionExpired].
class AuthRefreshInterceptor extends Interceptor {
  AuthRefreshInterceptor({
    required this.dio,
    required this.refreshIdToken,
    required this.markSessionExpired,
  });

  /// Marca em `RequestOptions.extra` que a request já foi repetida — trava o
  /// laço refresh → 401 → refresh.
  static const String retriedKey = 'plpcg.authRefreshRetried';

  /// O mesmo [Dio] em que este interceptor está instalado.
  final Dio dio;

  /// Devolve um `id_token` novo, ou `null`/vazio quando não foi possível.
  final Future<String?> Function() refreshIdToken;

  final void Function() markSessionExpired;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401) return handler.next(err);
    if (options.headers['Authorization'] == null) return handler.next(err);

    if (options.extra[retriedKey] == true) {
      // Já tentamos com token novo e o Worker recusou de novo.
      debugPrint('[auth] 401 mesmo após refresh — sessão expirada');
      markSessionExpired();
      return handler.next(err);
    }

    String? token;
    try {
      token = await refreshIdToken();
    } on Object catch (error) {
      // Nunca troca o 401 do chamador por um erro do refresh.
      debugPrint('[auth] refresh durante 401 falhou: $error');
    }
    if (token == null || token.isEmpty) return handler.next(err);

    options.extra[retriedKey] = true;
    options.headers['Authorization'] = 'Bearer $token';

    try {
      handler.resolve(await dio.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
