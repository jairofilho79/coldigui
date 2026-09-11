import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/presentation/providers/open_material_provider.dart';
import '../../../pdf_reader/presentation/providers/reader_carousel_actions_provider.dart';

/// Abre [materialId] no leitor via
/// [ReaderCarouselActionsNotifier.navigateToPdfId].
///
/// [navigate] recebe a rota `/leitor?...` — use `context.push` no shell ou
/// `context.replace` quando já estiver no leitor. Não aguarde o `Future` do
/// `push` até o `pop` da rota; [CarouselChips] mantém `_openingReader` apenas
/// durante resolve + disparo da navegação.
///
/// A escada de exceções de abertura vive em [presentMaterialOpenError].
Future<void> openCarouselPdfInReader({
  required WidgetRef ref,
  required BuildContext context,
  required String materialId,
  required Future<void> Function(String location) navigate,
}) async {
  final l10n = AppLocalizations.of(context);
  try {
    final location = await ref
        .read(readerCarouselActionsProvider.notifier)
        .navigateToPdfId(targetPdfId: materialId);
    if (!context.mounted) return;

    if (location == null) {
      showAppSnackbar(
        context,
        l10n?.pdfActionError ?? 'Não foi possível concluir a ação',
      );
      return;
    }

    await navigate(location);
  } on Object catch (error) {
    if (context.mounted) presentMaterialOpenError(context, l10n, error);
  }
}
