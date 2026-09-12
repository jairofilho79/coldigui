import 'dart:async';

import 'package:coldigui/core/failures/app_failure.dart';
import 'package:coldigui/core/l10n/failure_message.dart';
import 'package:coldigui/core/presentation/widgets/reader_split_layout.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/utils/share_position_origin.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';
import 'package:coldigui/core/widgets/app_snackbar.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/carousel/presentation/utils/open_carousel_pdf_in_reader.dart';
import 'package:coldigui/features/carousel/presentation/widgets/active_list_panel.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_material_lookup_provider.dart';
import 'package:coldigui/features/offline/data/providers/offline_providers.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/routing/shell_navigation.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/offline/presentation/utils/pdf_offline_error_ui.dart';
import 'package:coldigui/features/pdf_opening/data/providers/pdf_opening_providers.dart';
import 'package:coldigui/features/pdf_opening/domain/utils/louvor_pdf_path.dart';
import 'package:coldigui/features/pdf_reader/data/models/pdf_reader_viewer_handle.dart';
import 'package:coldigui/features/pdf_reader/data/providers/pdf_reader_viewer_providers.dart';
import 'package:coldigui/features/pdf_reader/domain/entities/pdf_reader_preferences.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/pdf_local_read_failed_exception.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_reader_view_settings_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_adjacent_pdf_prefetch_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_route_params_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_side_panel_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/widgets/pdf_page_skeleton.dart';
import 'package:coldigui/features/pdf_reader/presentation/widgets/pdf_reader_page_indicator.dart';
import 'package:coldigui/features/pdf_reader/presentation/widgets/pdf_reader_page_key_handler.dart';
import 'package:coldigui/features/pdf_reader/presentation/widgets/pdf_reader_pdf_view.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Query param que, se presente na rota, sinaliza uma página específica
/// pedida explicitamente (deep link) — desliga a restauração da última
/// página lembrada (spec A.3 C8).
const _pageQueryParam = 'page';

/// Debounce do salvamento da última página vista (spec A.3 C8).
const _saveLastPageDebounce = Duration(milliseconds: 500);

/// UC-11 — Leitor PDF (pdfrx), rota filha do [ShellScaffold].
///
/// Barras 1–2 (PLPCG + carousel) vêm do shell compartilhado. Esta tela renderiza
/// apenas a barra 3 — toolbar PDF — e a área do documento.
///
/// Fit mode é reaplicado pós-frame quando a sessão PDF carrega ou ao alternar
/// fullscreen ([readerFullscreenProvider]).
///
/// Long-press no indicador `page/total` da barra 3 navega para a primeira página
/// via [PdfReaderViewerHandle.goToFirstPage]; no-op se `page == 1`.
///
/// Recebe query params da rota `/leitor` — chaves em [UrlSyncParams]:
/// [UrlSyncParams.file], [UrlSyncParams.pdfId], [UrlSyncParams.titulo],
/// [UrlSyncParams.subtitulo], [UrlSyncParams.validated].
///
/// Publica os mesmos params em [readerRouteParamsProvider] (post-frame) para
/// [CarouselChips] no [ShellScaffold] sincronizar navegação carousel.
class PdfReaderScreen extends ConsumerStatefulWidget {
  const PdfReaderScreen({required this.queryParams, super.key});

  /// Parâmetros de query repassados pelo [appRouterProvider].
  final Map<String, String> queryParams;

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  String? _appliedFitForPath;
  String? _restoredLastPageForPath;
  Timer? _saveLastPageTimer;
  var _shareLoading = false;
  var _redownloadLoading = false;

  @override
  void initState() {
    super.initState();
    _schedulePublishRouteParams();
  }

  @override
  void didUpdateWidget(covariant PdfReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queryParams != widget.queryParams) {
      _schedulePublishRouteParams();
    }
  }

  @override
  void dispose() {
    _saveLastPageTimer?.cancel();
    super.dispose();
  }

  void _schedulePublishRouteParams() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(readerRouteParamsProvider.notifier).update(widget.queryParams);
    });
  }

  void _scheduleApplyInitialFit(PdfReaderViewerHandle sessionHandle) {
    void applyFit() {
      if (!mounted) return;
      final currentFilePath = widget.queryParams[UrlSyncParams.file] ?? '';
      final currentSession = ref
          .read(pdfReaderSessionProvider(currentFilePath))
          .value;
      if (currentSession == null ||
          !identical(currentSession.handle, sessionHandle)) {
        return;
      }
      if (!sessionHandle.isViewerReady) {
        return;
      }
      ref.read(pdfReaderViewSettingsProvider.notifier).applyInitialFit();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => applyFit());
  }

  /// Restaura a última página lembrada — uma vez por abertura de documento,
  /// pós-frame (após `onViewerReady`), só quando a rota não traz
  /// [_pageQueryParam] (spec A.3 C8).
  void _scheduleRestoreLastPage(PdfReaderSession session, String pdfId) {
    if (_restoredLastPageForPath == session.filePath) return;

    void restore() {
      if (!mounted) return;
      final currentFilePath = widget.queryParams[UrlSyncParams.file] ?? '';
      final currentSession = ref
          .read(pdfReaderSessionProvider(currentFilePath))
          .value;
      if (currentSession == null ||
          !identical(currentSession.handle, session.handle)) {
        return;
      }
      if (!session.handle.isViewerReady) return;
      _restoredLastPageForPath = session.filePath;

      if (widget.queryParams.containsKey(_pageQueryParam)) return;
      if (pdfId.isEmpty) return;

      final pagesCount = session.handle.pagesCount ?? 0;
      if (pagesCount <= 1) return;

      final savedPage = ref
          .read(readerPreferencesDatasourceProvider)
          .lastPageFor(pdfId);
      if (savedPage == null || savedPage <= 1 || savedPage > pagesCount) {
        return;
      }

      session.handle.animateToPage(pageNumber: savedPage);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => restore());
  }

  /// Salva a página vista com debounce (spec A.3 C8) — cancelado no dispose.
  void _handlePageChanged(int page, String pdfId) {
    if (pdfId.isEmpty) return;
    _saveLastPageTimer?.cancel();
    _saveLastPageTimer = Timer(_saveLastPageDebounce, () {
      ref.read(readerPreferencesDatasourceProvider).saveLastPage(pdfId, page);
    });
  }

  Future<void> _sharePdf(
    String filePath,
    String displayName, {
    Rect? sharePositionOrigin,
  }) async {
    if (_shareLoading) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _shareLoading = true);
    try {
      await ref
          .read(sharePdfProvider)
          .call(
            filePath: filePath,
            displayName: displayName,
            sharePositionOrigin: sharePositionOrigin,
          );
      if (mounted) {
        showAppSnackbar(
          context,
          l10n?.pdfShareSuccess ?? 'PDF pronto para compartilhar',
        );
      }
    } on Object {
      if (mounted) {
        showAppSnackbar(
          context,
          l10n?.pdfActionError ?? 'Não foi possível concluir a ação',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _shareLoading = false);
      }
    }
  }

  Future<void> _redownloadCorruptedPdf(String pdfId) async {
    if (_redownloadLoading) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _redownloadLoading = true);
    try {
      final louvor = ref.read(catalogMaterialLookupProvider).louvor(pdfId);
      if (louvor == null) {
        if (mounted) {
          showAppSnackbar(
            context,
            l10n?.pdfActionError ?? 'Não foi possível concluir a ação',
          );
        }
        return;
      }

      final remotePath = LouvorPdfPath.fromLouvor(louvor);
      final source = await ref.read(resolvePdfForReaderProvider)(
        pdfId: pdfId,
        remotePath: remotePath,
      );
      if (!mounted) return;

      final location = ref
          .read(openPdfInReaderProvider)
          .call(
            pdfPath: source.absolutePath,
            pdfId: louvor.pdfId,
            titulo: louvor.nome,
          );
      context.replace(location);
    } on PdfExternallyDeletedException {
      // Caso especial (fix round 1): PdfExternallyDeletedException tem texto
      // e ação ("Baixar") próprios — `l10n.pdfExternallyDeleted` é mais
      // específico que o genérico de `NotFoundFailure`/`failureNotFound`.
      // A exceção não carrega mais literal PT: o texto vem do l10n (D.6).
      if (mounted) {
        showPdfOfflineUnavailableSnackbar(
          context,
          message: l10n?.pdfExternallyDeleted,
        );
      }
    } on Object catch (error) {
      // Escada única via AppFailure (E8): a mensagem sai de `failureMessage`
      // — `OfflineFailure` mantém a snackbar com ação "Baixar", as demais
      // caem na snackbar genérica.
      if (mounted) {
        final failure = AppFailure.from(error);
        final message = l10n == null ? null : failureMessage(l10n, failure);
        if (failure is OfflineFailure) {
          showPdfOfflineUnavailableSnackbar(context, message: message);
        } else {
          showAppSnackbar(
            context,
            message ?? 'Não foi possível concluir a ação',
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _redownloadLoading = false);
      }
    }
  }

  /// Toque num item do painel lateral (A.6 C7): mesma ação das chips — foca a
  /// ocorrência (já feito por [ActiveListPanel]) e troca o material aberto no
  /// leitor. No-op quando o item tocado já é o material aberto (só a
  /// ocorrência focada muda).
  Future<void> _openFromPanel(CarouselItem item) async {
    final currentPdfId = widget.queryParams[UrlSyncParams.pdfId] ?? '';
    if (currentPdfId.isNotEmpty && item.materialId == currentPdfId) return;

    await openCarouselPdfInReader(
      ref: ref,
      context: context,
      materialId: item.materialId,
      navigate: (location) async {
        if (!mounted) return;
        context.replace(location);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.queryParams[UrlSyncParams.titulo] ?? 'Leitor PDF';
    final filePath = widget.queryParams[UrlSyncParams.file] ?? '';
    final pdfId = widget.queryParams[UrlSyncParams.pdfId] ?? '';
    final l10n = AppLocalizations.of(context);

    final carouselEmpty = ref.watch(carouselItemsProvider).isEmpty;
    final sidePanelOpen = ref.watch(readerSidePanelOpenProvider);
    final panel = ActiveListPanel(onOpen: _openFromPanel);

    if (filePath.trim().isEmpty) {
      return _ReaderScaffold(
        titulo: titulo,
        showTitle: carouselEmpty,
        panel: panel,
        sidePanelOpen: sidePanelOpen,
        onToggleSidePanel: () =>
            ref.read(readerSidePanelOpenProvider.notifier).toggle(),
        sidePanelTooltip: sidePanelOpen
            ? (l10n?.readerSidePanelHideTooltip ?? 'Ocultar lista (painel)')
            : (l10n?.readerSidePanelShowTooltip ?? 'Mostrar lista (painel)'),
        body: const _ReaderMessage(message: 'Parâmetro file ausente na URL'),
      );
    }

    final isFullscreen = ref.watch(readerFullscreenProvider);

    if (pdfId.isNotEmpty) {
      ref.watch(
        readerAdjacentPdfPrefetchProvider(
          ReaderAdjacentPdfPrefetchParams(filePath: filePath, pdfId: pdfId),
        ),
      );
    }

    final sessionAsync = ref.watch(pdfReaderSessionProvider(filePath));

    ref.listen(pdfReaderSessionProvider(filePath), (previous, next) {
      next.whenData((session) {
        if (_appliedFitForPath != session.filePath) {
          _appliedFitForPath = session.filePath;
          _scheduleApplyInitialFit(session.handle);
        }
        _scheduleRestoreLastPage(session, pdfId);
      });
    });

    ref.listen(readerFullscreenProvider, (previous, next) {
      if (previous == next) return;
      final session = ref.read(pdfReaderSessionProvider(filePath)).value;
      if (session == null) return;
      _scheduleApplyInitialFit(session.handle);
    });

    final sessionLoaded = sessionAsync.maybeWhen(
      data: (_) => true,
      orElse: () => false,
    );
    final sessionLoading = sessionAsync.isLoading;
    final fitMode = ref.watch(
      pdfReaderViewSettingsProvider.select((settings) => settings.fitMode),
    );
    final spreadEnabled = ref.watch(
      pdfReaderViewSettingsProvider.select(
        (settings) => settings.spreadEnabled,
      ),
    );

    return _ReaderScaffold(
      titulo: titulo,
      showTitle: sessionLoading && carouselEmpty,
      isFullscreen: isFullscreen,
      filePath: sessionLoaded ? filePath : null,
      panel: panel,
      sidePanelOpen: sidePanelOpen,
      onToggleSidePanel: () =>
          ref.read(readerSidePanelOpenProvider.notifier).toggle(),
      sidePanelTooltip: sidePanelOpen
          ? (l10n?.readerSidePanelHideTooltip ?? 'Ocultar lista (painel)')
          : (l10n?.readerSidePanelShowTooltip ?? 'Mostrar lista (painel)'),
      onToggleFullscreen: () => ref.read(toggleReaderFullscreenProvider).call(),
      onToggleFitMode: () =>
          ref.read(pdfReaderViewSettingsProvider.notifier).toggleFitMode(),
      fitModeIsPageWidth: fitMode == PdfFitMode.pageWidth,
      onToggleSpread: () =>
          ref.read(pdfReaderViewSettingsProvider.notifier).toggleSpread(),
      spreadEnabled: spreadEnabled,
      onShare: sessionLoaded
          ? (origin) => _sharePdf(filePath, titulo, sharePositionOrigin: origin)
          : null,
      shareLoading: _shareLoading,
      shareTooltip: l10n?.sharePdf ?? 'Compartilhar',
      fullscreenTooltip: l10n?.readerFullscreenTooltip ?? 'Tela cheia (F)',
      exitFullscreenTooltip:
          l10n?.readerExitFullscreenTooltip ?? 'Sair da tela cheia (Esc)',
      fitModeTooltip:
          l10n?.readerFitModeTooltip ?? 'Ajustar largura/página (Z)',
      moreOptionsTooltip: l10n?.readerMoreOptionsTooltip ?? 'Mais opções',
      spreadToggleLabel:
          l10n?.readerSpreadToggleLabel ?? 'Duas páginas em tela larga',
      body: sessionAsync.when(
        loading: () => const PdfPageSkeleton(),
        error: (error, _) {
          final unwrapped = unwrapProviderError(error);
          if (unwrapped is PdfLocalCorruptedException) {
            return _ReaderMessage(
              // Sem literal PT na exceção: o texto sai do l10n (D.6).
              message:
                  l10n?.pdfLocalCorrupted ?? pdfReaderErrorMessage(unwrapped),
              retryLabel: _redownloadLoading ? null : 'Baixar novamente',
              onRetry: _redownloadLoading
                  ? null
                  : () => _redownloadCorruptedPdf(unwrapped.pdfId),
            );
          }
          if (unwrapped is PdfOfflineUnavailableException ||
              unwrapped is PdfExternallyDeletedException) {
            return _ReaderMessage(
              message: unwrapped is PdfExternallyDeletedException
                  ? (l10n?.pdfExternallyDeleted ??
                        pdfReaderErrorMessage(unwrapped))
                  : pdfReaderErrorMessage(unwrapped),
              retryLabel: l10n?.pdfOfflineGoToSettings ?? 'Baixar',
              onRetry: () => goToShellDestination(context, RoutePaths.offline),
            );
          }
          return _ReaderMessage(
            message: unwrapped is PdfLocalReadFailedException
                ? (l10n?.pdfLocalReadFailedMessage ?? unwrapped.message)
                : pdfReaderErrorMessage(unwrapped),
            onRetry: () => ref.invalidate(pdfReaderSessionProvider(filePath)),
          );
        },
        data: (session) => PdfReaderPdfView(
          handle: session.handle,
          requiresReattach: session.fromCache,
          navigateToPage: (pageNumber) =>
              session.handle.animateToPage(pageNumber: pageNumber),
          refreshViewportAfterNavigation: () => ref
              .read(pdfReaderViewSettingsProvider.notifier)
              .applyInitialFit(),
          onPageChanged: (page) => _handlePageChanged(page, pdfId),
        ),
      ),
    );
  }
}

/// Toolbar do leitor (barra 3) + área PDF — inserido no [ShellScaffold].
///
/// Em fullscreen, oculta a barra 3 e exibe FAB de saída (`Icons.fullscreen_exit`)
/// com `Opacity(0.25)` no widget inteiro (fundo preto + ícone branco).
///
/// Indicador de página ([PdfReaderPageIndicator] na barra 3): long-press no texto
/// `page/total` navega para a primeira página; valor segue [PdfReaderViewerHandle.pageListenable].
class _ReaderScaffold extends StatelessWidget {
  const _ReaderScaffold({
    required this.titulo,
    required this.showTitle,
    required this.body,
    required this.panel,
    this.isFullscreen = false,
    this.filePath,
    this.onToggleFullscreen,
    this.onToggleFitMode,
    this.fitModeIsPageWidth = false,
    this.onToggleSpread,
    this.spreadEnabled = true,
    this.onToggleSidePanel,
    this.sidePanelOpen = true,
    this.sidePanelTooltip,
    this.onShare,
    this.shareLoading = false,
    this.shareTooltip,
    this.fullscreenTooltip,
    this.exitFullscreenTooltip,
    this.fitModeTooltip,
    this.moreOptionsTooltip,
    this.spreadToggleLabel,
  });

  final String titulo;
  final bool showTitle;
  final bool isFullscreen;
  final Widget body;
  final String? filePath;
  final VoidCallback? onToggleFullscreen;

  /// UC-11 — Ajustar à largura/página (spec A.3 C8, `Icons.fit_screen`).
  final VoidCallback? onToggleFitMode;

  /// `true` quando o fit atual é page-width — decide o ícone preenchido vs. contorno.
  final bool fitModeIsPageWidth;

  /// Alterna «duas páginas em tela larga» — item no menu (spec A.4 C8).
  final VoidCallback? onToggleSpread;

  /// `true` quando o spread está ligado — decide a marca de seleção do item.
  final bool spreadEnabled;

  /// Painel lateral com a lista ativa (spec A.6 C7) — ver [ReaderSplitLayout].
  final Widget panel;

  /// Alterna [readerSidePanelOpenProvider] (`Icons.view_sidebar`).
  final VoidCallback? onToggleSidePanel;

  /// `true` quando o painel está ligado — só decide o tooltip do botão; a
  /// visibilidade de fato é do [ReaderSplitLayout] (largura + fullscreen).
  final bool sidePanelOpen;
  final String? sidePanelTooltip;
  final void Function(Rect? sharePositionOrigin)? onShare;
  final bool shareLoading;
  final String? shareTooltip;
  final String? fullscreenTooltip;
  final String? exitFullscreenTooltip;
  final String? fitModeTooltip;

  /// Tooltip do botão de menu (`Icons.more_vert`) que abre o item de spread.
  final String? moreOptionsTooltip;

  /// Rótulo do item «Duas páginas em tela larga» no menu.
  final String? spreadToggleLabel;

  /// Roda a ação da barra 3 e devolve o foco ao handler de teclado do leitor.
  ///
  /// Sem isto o foco fica no botão que acabou de ser clicado e as setas param
  /// de virar página — o caso mais comum de "o teclado parou de funcionar".
  void _runAndRestoreKeyboardFocus(VoidCallback action) {
    action();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestPdfReaderKeyboardFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pdfArea = ColoredBox(color: AppColors.pdfArea, child: body);

    return Column(
      children: [
        if (!isFullscreen)
          SizedBox(
            height: kToolbarHeight,
            child: AppBar(
              primary: false,
              automaticallyImplyLeading: false,
              toolbarHeight: kToolbarHeight,
              title: showTitle
                  ? Text(titulo, overflow: TextOverflow.ellipsis)
                  : null,
              actions: [
                if (onShare != null)
                  Builder(
                    builder: (buttonContext) {
                      return IconButton(
                        tooltip: shareTooltip,
                        onPressed: shareLoading
                            ? null
                            : () => _runAndRestoreKeyboardFocus(
                                () => onShare!(
                                  sharePositionOriginFromContext(buttonContext),
                                ),
                              ),
                        icon: shareLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.share),
                      );
                    },
                  ),
                if (onToggleFitMode != null)
                  IconButton(
                    tooltip: fitModeTooltip ?? 'Ajustar largura/página (Z)',
                    icon: Icon(
                      fitModeIsPageWidth
                          ? Icons.fit_screen
                          : Icons.fit_screen_outlined,
                    ),
                    onPressed: () =>
                        _runAndRestoreKeyboardFocus(onToggleFitMode!),
                  ),
                if (onToggleFullscreen != null)
                  IconButton(
                    tooltip: fullscreenTooltip ?? 'Tela cheia (F)',
                    icon: const Icon(Icons.fullscreen),
                    onPressed: () =>
                        _runAndRestoreKeyboardFocus(onToggleFullscreen!),
                  ),
                if (onToggleSpread != null)
                  PopupMenuButton<void>(
                    tooltip: moreOptionsTooltip ?? 'Mais opções',
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      CheckedPopupMenuItem<void>(
                        checked: spreadEnabled,
                        onTap: () =>
                            _runAndRestoreKeyboardFocus(onToggleSpread!),
                        child: Text(
                          spreadToggleLabel ?? 'Duas páginas em tela larga',
                        ),
                      ),
                    ],
                  ),
                if (onToggleSidePanel != null)
                  IconButton(
                    tooltip: sidePanelTooltip,
                    icon: const Icon(Icons.view_sidebar),
                    isSelected: sidePanelOpen,
                    onPressed: () =>
                        _runAndRestoreKeyboardFocus(onToggleSidePanel!),
                  ),
                if (filePath != null)
                  PdfReaderPageIndicator(filePath: filePath!),
              ],
            ),
          ),
        Expanded(
          child: ReaderSplitLayout(
            panel: ColoredBox(color: AppColors.card, child: panel),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(child: pdfArea),
                if (isFullscreen)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Opacity(
                      opacity: 0.25,
                      child: FloatingActionButton(
                        tooltip:
                            exitFullscreenTooltip ?? 'Sair da tela cheia (Esc)',
                        elevation: 0,
                        highlightElevation: 0,
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        onPressed: onToggleFullscreen == null
                            ? null
                            : () => _runAndRestoreKeyboardFocus(
                                onToggleFullscreen!,
                              ),
                        child: const Icon(Icons.fullscreen_exit),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReaderMessage extends StatelessWidget {
  const _ReaderMessage({
    required this.message,
    this.onRetry,
    this.retryLabel = 'Tentar novamente',
  });

  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: const TextStyle(color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null && retryLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: Text(retryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
