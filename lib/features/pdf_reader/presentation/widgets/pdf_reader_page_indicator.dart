import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/pdf_reader_viewer_handle.dart';
import '../providers/pdf_reader_document_provider.dart';
import '../providers/pdf_reader_view_settings_provider.dart';
import 'go_to_page_dialog.dart';

/// Indicador `page/total` da barra 3 — escuta [PdfReaderViewerHandle.pageListenable]
/// diretamente para ficar sempre sincronizado com scroll e navegação programática.
///
/// Toque abre [GoToPageDialog] (spec A.3 C16); long-press volta à primeira
/// página já no ajuste efetivo ([PdfReaderViewerHandle.goToFirstPage]).
class PdfReaderPageIndicator extends ConsumerWidget {
  /// Query param [UrlSyncParams.file] da rota `/leitor` — chave do provider family.
  const PdfReaderPageIndicator({required this.filePath, super.key});

  final String filePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(pdfReaderSessionProvider(filePath));

    return sessionAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (session) {
        final handle = session.handle;
        return ValueListenableBuilder<PdfReaderLoadingState>(
          valueListenable: handle.loadingState,
          builder: (context, loadingState, _) {
            if (loadingState != PdfReaderLoadingState.success) {
              return const SizedBox.shrink();
            }

            return ValueListenableBuilder<int>(
              valueListenable: handle.pageListenable,
              builder: (context, displayedPage, _) {
                final pagesCount = handle.pagesCount ?? 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: GestureDetector(
                      onTap: pagesCount > 1
                          ? () => _openGoToPageDialog(
                              context,
                              handle: handle,
                              displayedPage: displayedPage,
                              pagesCount: pagesCount,
                            )
                          : null,
                      // O ajuste efetivo vai junto: o último trecho já
                      // chega na página 1 enquadrada (desfaz pinch) — antes,
                      // um `applyInitialFit` depois da chegada fazia um
                      // segundo movimento (zoom) visível.
                      onLongPress: displayedPage > 1
                          ? () => handle.goToFirstPage(
                              fitMode: ref.read(
                                pdfReaderEffectiveFitModeProvider,
                              ),
                            )
                          : null,
                      child: Text(
                        '$displayedPage/$pagesCount',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Abre [GoToPageDialog] e navega, se o usuário confirmar uma página válida
/// diferente da atual (spec A.3 C16).
Future<void> _openGoToPageDialog(
  BuildContext context, {
  required PdfReaderViewerHandle handle,
  required int displayedPage,
  required int pagesCount,
}) async {
  final target = await GoToPageDialog.show(
    context,
    pageCount: pagesCount,
    initialPage: displayedPage,
  );
  if (target == null || target == displayedPage) return;
  await handle.animateToPage(pageNumber: target);
}
