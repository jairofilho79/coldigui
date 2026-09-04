import 'dart:math';

import 'package:dio/dio.dart';

import '../constants/offline_config.dart';

/// Veredito único de "falha transitória" do app.
///
/// Mora no core porque tem dois donos: os downloads offline (PDF, ZIP) e o
/// [RetryInterceptor] do Dio, que é core e não pode depender de `features/`.
/// A cópia canônica ficava em `features/offline/domain/utils/`, que hoje só
/// reexporta daqui.
///
/// Indica se [e] é transitória e vale retentar (rede, timeout, HTTP ≥ 500).
bool isRetryableDioException(DioException e) {
  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout) {
    return true;
  }

  final statusCode = e.response?.statusCode;
  return statusCode != null && statusCode >= 500;
}

/// Backoff exponencial com jitter (±30%) para retentativas de download.
Duration retryDelayForAttempt(int attempt, [Random? random]) {
  final jitter = (random ?? Random()).nextDouble() * 0.3;
  final delay =
      OfflineConfig.retryBackoffBase * (1 << (attempt - 1)) * (1.0 + jitter);
  if (delay > OfflineConfig.maxRetryDelay) {
    return OfflineConfig.maxRetryDelay;
  }
  if (delay < Duration.zero) {
    return Duration.zero;
  }
  return delay;
}
