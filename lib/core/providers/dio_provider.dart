import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/entities/auth_user.dart';
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
      // `exp` do id_token guardado: renovar às vésperas do vencimento evita o
      // 401 (e a request repetida) na maioria das vezes. Token sem sessão ou
      // sem `exp` legível devolve `false` — aí só o 401 renova.
      tokenExpiresSoon: () {
        final user = ref.read(authStateProvider).asData?.value;
        return user != null && user.expiresSoon;
      },
      isSessionExpired: () => ref.read(sessionExpiredProvider),
      markSessionExpired: () =>
          ref.read(sessionExpiredProvider.notifier).markExpired(),
    ),
    RetryInterceptor(dio: dio),
  ]);

  return dio;
});
