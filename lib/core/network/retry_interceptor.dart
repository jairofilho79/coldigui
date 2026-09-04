import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Retenta requests **idempotentes** que falharam por motivo transitório.
///
/// Só `GET`: repetir um `POST`/`PUT`/`DELETE` que já chegou ao servidor
/// duplicaria efeito. Só erro de conexão, timeout ou 5xx — 4xx é resposta
/// definitiva (401 é caso do `AuthRefreshInterceptor`).
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.dio,
    this.maxRetries = 2,
    this.backoff = defaultBackoff,
    this.sleep = _wait,
  });

  /// Espera entre a 1ª e a 2ª retentativa. Retentativas além do fim da lista
  /// reusam o último intervalo.
  static const List<Duration> defaultBackoff = [
    Duration(milliseconds: 300),
    Duration(milliseconds: 900),
  ];

  /// Contador de retentativas por request (vive em `RequestOptions.extra`).
  static const String attemptKey = 'plpcg.retryAttempt';

  /// O mesmo [Dio] em que este interceptor está instalado — é por ele que a
  /// retentativa sai, para herdar baseUrl, timeouts e os demais interceptors.
  final Dio dio;
  final int maxRetries;
  final List<Duration> backoff;

  /// Costura de teste: substituível para não gastar tempo real de espera.
  final Future<void> Function(Duration) sleep;

  static Future<void> _wait(Duration duration) =>
      Future<void>.delayed(duration);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (!_isRetryable(err)) return handler.next(err);

    final attempt = (options.extra[attemptKey] as int?) ?? 0;
    if (attempt >= maxRetries) return handler.next(err);

    await sleep(
      backoff.isEmpty
          ? Duration.zero
          : backoff[attempt.clamp(0, backoff.length - 1)],
    );

    options.extra[attemptKey] = attempt + 1;
    debugPrint(
      '[rede] retentativa ${attempt + 1}/$maxRetries em '
      '${options.method} ${options.path}: ${err.type.name}',
    );

    try {
      handler.resolve(await dio.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _isRetryable(DioException err) {
    if (err.requestOptions.method.toUpperCase() != 'GET') return false;
    return switch (err.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => true,
      DioExceptionType.badResponse => (err.response?.statusCode ?? 0) >= 500,
      // cancel/badCertificate/transformTimeout/unknown não melhoram repetindo.
      _ => false,
    };
  }
}
