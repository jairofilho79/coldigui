import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_state_provider.dart';
import '../constants/app_config.dart';
import '../network/auth_refresh_interceptor.dart';
import '../network/retry_interceptor.dart';

/// Cliente HTTP Dio para endpoints Cloudflare (manifest, PDFs, ZIPs).
///
/// [BaseOptions.baseUrl] vem de [AppConfig.apiBaseUrl]
/// (`--dart-define=PLPCG_API_BASE_URL`).
///
/// Interceptors (nesta ordem): [AuthRefreshInterceptor] resolve o 401 antes de
/// o [RetryInterceptor] ver o erro — repetir um 401 sem token novo só gastaria
/// tentativa. Todos os datasources que passam por aqui (playlists, social,
/// audio_flags, catálogo, PDFs) herdam os dois.
///
/// O [AuthRefreshInterceptor] age nas duas pontas da request:
/// - **antes de sair** ([AuthRefreshInterceptor.onRequest]): request com
///   `Authorization` e token às vésperas do vencimento (`tokenExpiresSoon`)
///   renova primeiro e sai já com o token novo — o 401 (e a repetição da
///   request) deixa de acontecer na maioria das vezes. Rota pública, sessão já
///   expirada ou token fora da janela passam direto.
/// - **depois do 401** ([AuthRefreshInterceptor.onError]): renova e repete a
///   request uma vez; sem token novo, marca a sessão como expirada.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  dio.interceptors.addAll([
    AuthRefreshInterceptor(
      dio: dio,
      // `read` (e não `watch`) de propósito: o Dio não deve ser recriado a cada
      // mudança de sessão, e a chamada só acontece dentro de um 401.
      refreshIdToken: () =>
          ref.read(authStateProvider.notifier).refreshIdToken(),
      // `sessionToken` é opaco (sem `exp` legível) — só o 401 renova.
      tokenExpiresSoon: () => false,
      isSessionExpired: () => ref.read(sessionExpiredProvider),
      markSessionExpired: () =>
          ref.read(sessionExpiredProvider.notifier).markExpired(),
    ),
    RetryInterceptor(dio: dio),
  ]);

  return dio;
});
