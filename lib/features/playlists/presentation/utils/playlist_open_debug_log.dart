import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Estágio da última falha ao abrir playlist no leitor — preenchido em
/// [kDebugMode] para [showPlaylistOpenErrorSnackbar].
String? playlistOpenLastStage;

/// Erro ou detalhe da última falha — preenchido em [kDebugMode] para
/// [playlistOpenDebugErrorSummary] e [showPlaylistOpenErrorSnackbar].
Object? playlistOpenLastError;

/// Limpa [playlistOpenLastStage] e [playlistOpenLastError] antes de nova
/// tentativa em [PlaylistListTile._openPdfInReader].
void playlistOpenDebugClearLastFailure() {
  playlistOpenLastStage = null;
  playlistOpenLastError = null;
}

/// Logs de diagnóstico UC-06 (abrir playlist no leitor) — apenas em
/// [kDebugMode]. Prefixo console: `[UC-06 playlist-open]`.
void playlistOpenDebugLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[UC-06 playlist-open] $message');
}

/// Registra exceção com stack no console; preenche [playlistOpenLastStage] e
/// [playlistOpenLastError] para resumo na snackbar em debug.
void playlistOpenDebugLogError(
  String stage,
  Object error,
  StackTrace stackTrace,
) {
  if (!kDebugMode) return;
  playlistOpenLastStage = stage;
  playlistOpenLastError = error;
  debugPrint('[UC-06 playlist-open] ERRO em $stage: $error');
  debugPrint('[UC-06 playlist-open] $stackTrace');
}

/// Registra falha lógica sem exceção — ex.: louvor ausente no manifest ou
/// [PlaylistsNotifier.loadIntoCarousel] retornou `false`.
void playlistOpenDebugLogFailure(String stage, String detail) {
  if (!kDebugMode) return;
  playlistOpenLastStage = stage;
  playlistOpenLastError = detail;
  debugPrint('[UC-06 playlist-open] FALHA em $stage: $detail');
}

/// Resumo curto `estágio — Tipo: mensagem` para snackbar em debug (sem stack).
String playlistOpenDebugErrorSummary() {
  final error = playlistOpenLastError;
  final stage = playlistOpenLastStage;
  if (error == null) return stage ?? 'erro desconhecido';
  final errorText =
      error.runtimeType == String ? '$error' : '${error.runtimeType}: $error';
  if (stage == null) return errorText;
  return '$stage — $errorText';
}

/// Snackbar de falha ao abrir playlist — [AppLocalizations.pdfActionError] com
/// resumo técnico de [playlistOpenDebugErrorSummary] em [kDebugMode] (8s).
void showPlaylistOpenErrorSnackbar(
  BuildContext context,
  AppLocalizations l10n,
) {
  final hasDebugDetail = kDebugMode && playlistOpenLastError != null;
  final message = hasDebugDetail
      ? '${l10n.pdfActionError}\n${playlistOpenDebugErrorSummary()}'
      : l10n.pdfActionError;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: hasDebugDetail
          ? const Duration(seconds: 8)
          : const Duration(seconds: 4),
    ),
  );
}
