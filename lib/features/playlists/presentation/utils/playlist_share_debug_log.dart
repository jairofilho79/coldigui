import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Última falha de compartilhamento — preenchido em [kDebugMode] para snackbar.
String? playlistShareLastStage;
Object? playlistShareLastError;

/// Limpa estado de diagnóstico antes de nova tentativa de share.
void playlistShareDebugClearLastFailure() {
  playlistShareLastStage = null;
  playlistShareLastError = null;
}

/// Logs de diagnóstico UC-07 — apenas em [kDebugMode].
void playlistShareDebugLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[UC-07 playlist-share] $message');
}

/// Erro + stack no console de debug; guarda resumo para UI em debug.
void playlistShareDebugLogError(
  String stage,
  Object error,
  StackTrace stackTrace,
) {
  if (!kDebugMode) return;
  playlistShareLastStage = stage;
  playlistShareLastError = error;
  debugPrint('[UC-07 playlist-share] ERRO em $stage: $error');
  debugPrint('[UC-07 playlist-share] $stackTrace');
}

/// Resumo curto do erro para snackbar em debug (sem stack).
String playlistShareDebugErrorSummary() {
  final error = playlistShareLastError;
  final stage = playlistShareLastStage;
  if (error == null) return stage ?? 'erro desconhecido';
  final errorText =
      error.runtimeType == String ? '$error' : '${error.runtimeType}: $error';
  if (stage == null) return errorText;
  return '$stage — $errorText';
}

/// Snackbar de falha no share — inclui resumo técnico em [kDebugMode].
void showPlaylistShareErrorSnackbar(
  BuildContext context,
  AppLocalizations l10n,
) {
  final hasDebugDetail = kDebugMode && playlistShareLastError != null;
  final message = hasDebugDetail
      ? '${l10n.playlistShareError}\n${playlistShareDebugErrorSummary()}'
      : l10n.playlistShareError;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: hasDebugDetail
          ? const Duration(seconds: 8)
          : const Duration(seconds: 4),
    ),
  );
}
