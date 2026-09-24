import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_state_provider.dart';
import '../constants/app_config.dart';
import '../network/auth_unauthorized_interceptor.dart';
import '../network/retry_interceptor.dart';

/// Cliente HTTP Dio para o Worker `plpcg-catalog` (playlists, social,
/// auth, favoritos) — o catálogo e o coldigom em geral (contribuições
/// incluídas) usam `coldigomDioProvider`.
///
/// [BaseOptions.baseUrl] vem de [AppConfig.apiBaseUrl]
/// (`--dart-define=PLPCG_API_BASE_URL`).
///
/// Interceptors (nesta ordem): [AuthUnauthorizedInterceptor] vê o 401 antes
/// de o [RetryInterceptor] ver o erro (401 não é repetido — sessão revogada
/// não volta sozinha). Todos os datasources que passam por aqui (playlists,
/// social, audio_flags, material_kind_prefs) herdam os dois.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  dio.interceptors.addAll([
    AuthUnauthorizedInterceptor(
      // `read` (e não `watch`) de propósito: o Dio não deve ser recriado a cada
      // mudança de sessão, e a chamada só acontece dentro de um 401.
      onUnauthorized: (token) =>
          ref.read(authStateProvider.notifier).onUnauthorized(token),
    ),
    RetryInterceptor(dio: dio),
  ]);

  return dio;
});
