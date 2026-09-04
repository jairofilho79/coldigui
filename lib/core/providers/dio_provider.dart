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
      isSessionExpired: () => ref.read(sessionExpiredProvider),
      markSessionExpired: () =>
          ref.read(sessionExpiredProvider.notifier).markExpired(),
    ),
    RetryInterceptor(dio: dio),
  ]);

  return dio;
});
