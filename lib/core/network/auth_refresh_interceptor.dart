import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Renova o `id_token` antes de a request sair (quando o `exp` está perto) e
/// de novo em cima de um 401, repetindo a request **uma** vez.
///
/// Só age em request que já mandou `Authorization`: 401 em rota pública é
/// resposta legítima. 403 não entra — é permissão, não token vencido.
///
/// O caminho preventivo é um atalho, nunca um bloqueio: se ele falhar, a
/// request segue com o token antigo e o 401 continua sendo a recuperação.
///
/// Se o refresh do 401 falhar, o 401 original volta ao chamador (quem marca a
/// sessão como expirada é o próprio refresh). Se a repetição levar 401 de novo,
/// o token novo também não serve: aí sim [markSessionExpired].
class AuthRefreshInterceptor extends Interceptor {
  AuthRefreshInterceptor({
    required this.dio,
    required this.refreshIdToken,
    required this.tokenExpiresSoon,
    required this.isSessionExpired,
    required this.markSessionExpired,
  });

  /// Marca em `RequestOptions.extra` que a request já foi repetida — trava o
  /// laço refresh → 401 → refresh.
  static const String retriedKey = 'plpcg.authRefreshRetried';

  /// O mesmo [Dio] em que este interceptor está instalado.
  final Dio dio;

  /// Devolve um `id_token` novo, ou `null`/vazio quando não foi possível.
  final Future<String?> Function() refreshIdToken;

  /// `true` quando o `id_token` da sessão atual vence dentro da janela de
  /// renovação (`AuthUserExpiry.expiresSoon`). Sem sessão, ou com token sem
  /// `exp` legível, é `false` — nesse caso só o 401 renova.
  final bool Function() tokenExpiresSoon;

  /// `true` quando um refresh já falhou nesta sessão — tentar de novo a cada
  /// 401 só repetiria o laço.
  final bool Function() isSessionExpired;

  final void Function() markSessionExpired;

  /// Refresh em voo — várias requests que saem juntas com o token vencendo
  /// compartilham uma renovação só, em vez de uma cada.
  Future<String?>? _refreshInFlight;

  /// Renova sem nunca propagar: quem chama decide o que fazer com `null`.
  Future<String?> _refresh(String stage) async {
    try {
      return await (_refreshInFlight ??= refreshIdToken().whenComplete(() {
        _refreshInFlight = null;
      }));
    } on Object catch (error) {
      debugPrint('[auth] refresh $stage falhou: $error');
      return null;
    }
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Rota pública não tem token para renovar; sessão já expirada não tem para
    // onde renovar. Fora da janela de vencimento, o token atual serve.
    if (options.headers['Authorization'] == null ||
        isSessionExpired() ||
        !tokenExpiresSoon()) {
      return handler.next(options);
    }

    final token = await _refresh('preventivo');
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401) return handler.next(err);
    if (options.headers['Authorization'] == null) return handler.next(err);

    // Sessão já marcada como expirada: o refresh não vai virar do avesso, e
    // insistir a cada request realimentaria o laço 401 → refresh → 401.
    if (isSessionExpired()) return handler.next(err);

    if (options.extra[retriedKey] == true) {
      // Já tentamos com token novo e o Worker recusou de novo.
      debugPrint('[auth] 401 mesmo após refresh — sessão expirada');
      markSessionExpired();
      return handler.next(err);
    }

    // `_refresh` nunca propaga: o 401 do chamador não vira outro erro.
    final token = await _refresh('durante 401');
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
