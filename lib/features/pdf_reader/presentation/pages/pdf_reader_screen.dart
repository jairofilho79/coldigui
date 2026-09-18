import 'dart:async';

import 'package:coldigui/core/failures/app_failure.dart';
import 'package:coldigui/core/l10n/failure_message.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/utils/share_position_origin.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';
import 'package:coldigui/core/widgets/app_snackbar.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/mini_player_bar_metrics.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_material_lookup_provider.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_kind.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_target.dart';
import 'package:coldigui/features/contributions/presentation/utils/open_contribute.dart';
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
/// Fit mode é aplicado quando o viewer fica pronto ([_handleViewerReady]) e
/// ao alternar fullscreen — nunca por virada de página (auditoria P3).
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
    clearSnackbarsOnEnter(context);
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

  /// Disparado por [PdfReaderPdfView.onViewerReady] — o único momento em que
  /// o controller pdfrx está de fato anexado (Important 2, onda 4: o antigo
  /// post-frame agendado na resolução da sessão corria antes disso e nunca
  /// era refeito, então fit inicial e restauração de página nunca aconteciam
  /// numa abertura real). Decide fit e restauração juntos, uma vez por
  /// documento.
  void _handleViewerReady(PdfReaderSession session, String pdfId) {
    if (!mounted) return;
    final currentFilePath = widget.queryParams[UrlSyncParams.file] ?? '';
    final currentSession = ref
        .read(pdfReaderSessionProvider(currentFilePath))
        .value;
    if (currentSession == null ||
        !identical(currentSession.handle, session.handle)) {
      return;
    }

    if (_appliedFitForPath != session.filePath) {
      _appliedFitForPath = session.filePath;
      ref.read(pdfReaderViewSettingsProvider.notifier).applyInitialFit();
    }

    _restoreLastPageOnce(session, pdfId);
  }

  /// Restaura a última página lembrada — uma vez por abertura de documento,
  /// só quando a rota não traz [_pageQueryParam] (spec A.3 C8). Marca a
  /// decisão mesmo quando não há nada a restaurar, para destravar
  /// [_handlePageChanged] (que fica suprimido até a decisão ser tomada).
  void _restoreLastPageOnce(PdfReaderSession session, String pdfId) {
    if (_restoredLastPageForPath == session.filePath) return;
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

  /// Salva a página vista com debounce (spec A.3 C8) — cancelado no dispose.
  ///
  /// Suprimido até a decisão de restauração (Important 2) ser tomada: sem
  /// isso, o `onPageChanged(1)` inicial do pdfrx sobrescrevia a página
  /// lembrada antes da restauração ter a chance de rodar.
  void _handlePageChanged(int page, String pdfId, String filePath) {
    if (pdfId.isEmpty) return;
    if (_restoredLastPageForPath != filePath) return;
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

      // Mantém o id que a rota já carregava: `louvor` pode ter vindo pelo
      // alias (id legado) e trocar o id aqui desalinharia carrossel e Live.
      final location = ref
          .read(openPdfInReaderProvider)
          .call(
            pdfPath: source.absolutePath,
            pdfId: pdfId,
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

  @override
  Widget build(BuildContext context) {
    final titulo = widget.queryParams[UrlSyncParams.titulo] ?? 'Leitor PDF';
    final filePath = widget.queryParams[UrlSyncParams.file] ?? '';
    final pdfId = widget.queryParams[UrlSyncParams.pdfId] ?? '';
    final l10n = AppLocalizations.of(context);

    final carouselEmpty = ref.watch(carouselItemsProvider).isEmpty;

    if (filePath.trim().isEmpty) {
      return _ReaderScaffold(
        titulo: titulo,
        showTitle: carouselEmpty,
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

    ref.listen(readerFullscreenProvider, (previous, next) {
      if (previous == next) return;
      final session = ref.read(pdfReaderSessionProvider(filePath)).value;
      if (session == null || !session.handle.isViewerReady) return;
      ref.read(pdfReaderViewSettingsProvider.notifier).applyInitialFit();
    });

    final sessionLoaded = sessionAsync.maybeWhen(
      data: (_) => true,
      orElse: () => false,
    );
    final sessionLoading = sessionAsync.isLoading;
    final fitMode = ref.watch(
      pdfReaderViewSettingsProvider.select((settings) => settings.fitMode),
    );
    // Important 3 (onda 4): mesma condição do overlay em `shell_scaffold.dart`
    // (hideChrome + faixa tocando) — reserva o espaço do mini-player para o
    // FAB de saída e o conteúdo não ficarem por baixo dele.
    final hasPlayingTrack = ref.watch(
      audioPlayerSessionProvider.select((s) => s.currentTrack != null),
    );
    final miniPlayerOverlayVisible = isFullscreen && hasPlayingTrack;

    // O botão «Reportar» só aparece quando dá pra montar um alvo — sem
    // `louvor` (pdfId vazio ou ainda não aquecido no lookup), a bandeirinha
    // some em vez de abrir o formulário sem contexto nenhum.
    final reportLouvor = pdfId.isEmpty
        ? null
        : ref.watch(catalogMaterialLookupProvider).louvor(pdfId);

    return _ReaderScaffold(
      titulo: titulo,
      showTitle: sessionLoading && carouselEmpty,
      isFullscreen: isFullscreen,
      miniPlayerOverlayVisible: miniPlayerOverlayVisible,
      filePath: sessionLoaded ? filePath : null,
      onToggleFullscreen: () => ref.read(toggleReaderFullscreenProvider).call(),
      onToggleFitMode: () =>
          ref.read(pdfReaderViewSettingsProvider.notifier).toggleFitMode(),
      fitModeIsPageWidth: fitMode == PdfFitMode.pageWidth,
      onShare: sessionLoaded
          ? (origin) => _sharePdf(filePath, titulo, sharePositionOrigin: origin)
          : null,
      shareLoading: _shareLoading,
      shareTooltip: l10n?.sharePdf ?? 'Compartilhar',
      onReport: reportLouvor == null
          ? null
          : () => openContribute(
              context,
              target: ContributionTarget(
                source: contributionSourceOf(
                  isColdigom: reportLouvor.source == LouvorDataSource.coldigom,
                ),
                praiseId: reportLouvor.groupId,
                materialId: pdfId,
              ),
            ),
      reportTooltip: l10n?.contributeReportTooltip ?? 'Reportar',
      fullscreenTooltip: l10n?.readerFullscreenTooltip ?? 'Tela cheia (F)',
      exitFullscreenTooltip:
          l10n?.readerExitFullscreenTooltip ?? 'Sair da tela cheia (Esc)',
      fitModeTooltip:
          l10n?.readerFitModeTooltip ?? 'Ajustar largura/página (Z)',
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
            // Sem literal PT na exceção (E8 fix round 1): o texto sai do
            // l10n; sem `context` cai no fallback genérico (D.6).
            message: unwrapped is PdfLocalReadFailedException
                ? (l10n?.pdfLocalReadFailedMessage ??
                      pdfReaderErrorMessage(unwrapped))
                : pdfReaderErrorMessage(unwrapped),
            onRetry: () => ref.invalidate(pdfReaderSessionProvider(filePath)),
          );
        },
        data: (session) => PdfReaderPdfView(
          handle: session.handle,
          requiresReattach: session.fromCache,
          navigateToPage: (pageNumber) =>
              session.handle.animateToPage(pageNumber: pageNumber),
          onPageChanged: (page) => _handlePageChanged(page, pdfId, filePath),
          onViewerReady: () => _handleViewerReady(session, pdfId),
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
    this.isFullscreen = false,
    this.miniPlayerOverlayVisible = false,
    this.filePath,
    this.onToggleFullscreen,
    this.onToggleFitMode,
    this.fitModeIsPageWidth = false,
    this.onShare,
    this.shareLoading = false,
    this.shareTooltip,
    this.onReport,
    this.reportTooltip,
    this.fullscreenTooltip,
    this.exitFullscreenTooltip,
    this.fitModeTooltip,
  });

  final String titulo;
  final bool showTitle;
  final bool isFullscreen;

  /// `true` quando o overlay [MiniPlayerBar] (44 px, `bottom: 0`) some em
  /// cima do FAB de saída e do conteúdo em fullscreen — mesma condição do
  /// overlay em `shell_scaffold.dart` (Important 3, onda 4).
  final bool miniPlayerOverlayVisible;
  final Widget body;
  final String? filePath;
  final VoidCallback? onToggleFullscreen;

  /// UC-11 — Ajustar à largura/página (spec A.3 C8, `Icons.fit_screen`).
  final VoidCallback? onToggleFitMode;

  /// `true` quando o fit atual é page-width — decide o ícone preenchido vs. contorno.
  final bool fitModeIsPageWidth;

  final void Function(Rect? sharePositionOrigin)? onShare;
  final bool shareLoading;
  final String? shareTooltip;

  /// UC — «Reportar» (contribuições da comunidade): `null` quando não dá pra
  /// resolver o louvor do `pdfId` da rota, e a bandeirinha some.
  final VoidCallback? onReport;
  final String? reportTooltip;
  final String? fullscreenTooltip;
  final String? exitFullscreenTooltip;
  final String? fitModeTooltip;

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
    // Important 3 (onda 4): o mini-player overlay some em `bottom: 0` com
    // 44 px de altura — sem este respiro o conteúdo fica coberto por ele.
    final pdfArea = ColoredBox(
      color: AppColors.pdfArea,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: miniPlayerOverlayVisible ? kMiniPlayerBarHeight : 0,
        ),
        child: body,
      ),
    );

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
                if (onReport != null)
                  IconButton(
                    tooltip: reportTooltip,
                    icon: const Icon(Icons.flag_outlined),
                    // Ação navega para fora do leitor — sem
                    // `_runAndRestoreKeyboardFocus`, que devolveria o foco de
                    // teclado a uma tela que já não está em cena.
                    onPressed: onReport,
                  ),
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
                if (filePath != null)
                  PdfReaderPageIndicator(filePath: filePath!),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: pdfArea),
              if (isFullscreen)
                Positioned(
                  right: 16,
                  bottom:
                      16 +
                      (miniPlayerOverlayVisible ? kMiniPlayerBarHeight : 0),
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
