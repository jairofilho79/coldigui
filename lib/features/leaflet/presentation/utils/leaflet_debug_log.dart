import 'package:flutter/foundation.dart';

/// Logs de diagnóstico UC-08 — apenas em [kDebugMode].
void leafletDebugLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[UC-08 leaflet] $message');
}

/// Erro + stack no console de debug.
void leafletDebugLogError(
  String stage,
  Object error,
  StackTrace stackTrace,
) {
  if (!kDebugMode) return;
  debugPrint('[UC-08 leaflet] ERRO em $stage: $error');
  debugPrint('[UC-08 leaflet] $stackTrace');
}

/// Resumo curto do erro para snackbar em debug (sem stack).
String leafletDebugErrorSummary(Object error) {
  return error.runtimeType == String
      ? '$error'
      : '${error.runtimeType}: $error';
}
