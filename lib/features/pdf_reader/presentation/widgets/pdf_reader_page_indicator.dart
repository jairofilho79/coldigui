import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

import '../providers/pdf_reader_displayed_page_provider.dart';
import '../providers/pdf_reader_document_provider.dart';

/// Indicador `page/total` da barra 3 — usa [pdfReaderDisplayedPageProvider]
/// para não piscar páginas intermediárias durante `animateToPage`.
///
/// Recompila quando [PdfControllerPinch.loadingState] passa a `success`, via
/// [ValueListenableBuilder], para exibir o texto logo após o PDF carregar.
class PdfReaderPageIndicator extends ConsumerWidget {
  /// Query param [UrlSyncParams.file] da rota `/leitor` — chave do provider family.
  const PdfReaderPageIndicator({required this.filePath, super.key});

  final String filePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(pdfReaderSessionProvider(filePath));

    return sessionAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (session) => ValueListenableBuilder<PdfLoadingState>(
        valueListenable: session.controller.loadingState,
        builder: (context, loadingState, _) {
          if (loadingState != PdfLoadingState.success) {
            return const SizedBox.shrink();
          }

          final displayedPage =
              ref.watch(pdfReaderDisplayedPageProvider(filePath));
          final notifier =
              ref.read(pdfReaderDisplayedPageProvider(filePath).notifier);
          final pagesCount =
              notifier.pagesCount ?? session.controller.pagesCount ?? 0;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: GestureDetector(
                onLongPress: displayedPage > 1
                    ? () => notifier.animateToPage(pageNumber: 1)
                    : null,
                child: Text(
                  '$displayedPage/$pagesCount',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
