import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../offline/domain/exceptions/pdf_resolve_exceptions.dart';
import '../../../pdf_reader/domain/exceptions/invalid_pdf_path_exception.dart';
import '../../../pdf_reader/presentation/providers/reader_carousel_actions_provider.dart';

/// Abre [pdfId] no leitor via [ReaderCarouselActionsNotifier.navigateToPdfId].
///
/// [navigate] recebe a rota `/leitor?...` — use `context.push` no shell ou
/// `context.replace` quando já estiver no leitor. Não aguarde o `Future` do
/// `push` até o `pop` da rota; [CarouselChips] mantém `_openingReader` apenas
/// durante resolve + disparo da navegação.
Future<void> openCarouselPdfInReader({
  required WidgetRef ref,
  required BuildContext context,
  required String pdfId,
  required Future<void> Function(String location) navigate,
}) async {
  final l10n = AppLocalizations.of(context);
  try {
    final location = await ref
        .read(readerCarouselActionsProvider.notifier)
        .navigateToPdfId(targetPdfId: pdfId);
    if (!context.mounted) return;

    if (location == null) {
      showAppSnackbar(
        context,
        l10n?.pdfActionError ?? 'Não foi possível concluir a ação',
      );
      return;
    }

    await navigate(location);
  } on InvalidPdfPathException {
    if (context.mounted) {
      showAppSnackbar(
        context,
        l10n?.pdfActionError ?? 'Não foi possível concluir a ação',
      );
    }
  } on PdfOfflineUnavailableException catch (e) {
    if (context.mounted) showAppSnackbar(context, e.message);
  } on PdfExternallyDeletedException catch (e) {
    if (context.mounted) showAppSnackbar(context, e.message);
  } on PdfFetchFailedException catch (e) {
    if (context.mounted) showAppSnackbar(context, e.message);
  } on Object {
    if (context.mounted) {
      showAppSnackbar(
        context,
        l10n?.pdfActionError ?? 'Não foi possível concluir a ação',
      );
    }
  }
}
