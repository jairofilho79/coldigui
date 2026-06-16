import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../l10n/app_localizations.dart';

/// Snackbar com ação para a tela offline quando o PDF não está disponível.
void showPdfOfflineUnavailableSnackbar(
  BuildContext context, {
  String? message,
}) {
  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message ??
            l10n?.pdfOfflineUnavailableMessage ??
            const PdfOfflineUnavailableMessageFallback().message,
      ),
      action: SnackBarAction(
        label: l10n?.pdfOfflineGoToSettings ?? 'Baixar',
        onPressed: () => context.push(RoutePaths.offline),
      ),
    ),
  );
}

/// Fallback quando [AppLocalizations] não está disponível (ex.: testes).
class PdfOfflineUnavailableMessageFallback {
  const PdfOfflineUnavailableMessageFallback();

  String get message => 'Este PDF não foi baixado para uso offline. '
      'Conecte-se à internet ou acesse Configurações Offline → Baixar Faltantes.';
}
