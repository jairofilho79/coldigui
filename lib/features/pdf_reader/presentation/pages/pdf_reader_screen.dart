import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/utils/share_position_origin.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';
import 'package:coldigui/core/widgets/app_snackbar.dart';
import 'package:coldigui/features/catalog/domain/utils/find_louvor_by_pdf_id.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:coldigui/features/offline/data/providers/offline_providers.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/offline/presentation/utils/pdf_offline_error_ui.dart';
import 'package:coldigui/features/pdf_opening/data/providers/pdf_opening_providers.dart';
import 'package:coldigui/features/pdf_opening/domain/utils/louvor_pdf_path.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_reader_view_settings_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_adjacent_pdf_prefetch_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_route_params_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_reader_displayed_page_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/widgets/pdf_page_skeleton.dart';
import 'package:coldigui/features/pdf_reader/presentation/widgets/pdf_reader_page_indicator.dart';
import 'package:coldigui/features/pdf_reader/presentation/widgets/pdfx_pdf_view.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart';

/// UC-11 — Leitor PDF (PDFx), rota filha do [ShellScaffold].
///
/// Barras 1–2 (PLPCG + carousel) vêm do shell compartilhado. Esta tela renderiza
/// apenas a barra 3 — toolbar PDF — e a área do documento.
///
/// Fit mode é reaplicado pós-frame quando a sessão PDF carrega ou ao alternar
/// fullscreen ([readerFullscreenProvider]).
///
/// Long-press no indicador `page/total` da barra 3 navega para a primeira página
/// via [PdfReaderDisplayedPageNotifier.animateToPage]; no-op se `page == 1`.
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

  void _schedulePublishRouteParams() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(readerRouteParamsProvider.notifier).update(widget.queryParams);
    });
  }

  void _scheduleApplyInitialFit(PdfControllerPinch sessionController) {
    void applyFit() {
      if (!mounted) return;
      final currentFilePath = widget.queryParams[UrlSyncParams.file] ?? '';
      final currentSession =
          ref.read(pdfReaderSessionProvider(currentFilePath)).valueOrNull;
      if (currentSession == null ||
          !identical(currentSession.controller, sessionController)) {
        return;
      }
      if (sessionController.loadingState.value != PdfLoadingState.success) {
        return;
      }
      ref.read(pdfReaderViewSettingsProvider.notifier).applyInitialFit();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => applyFit());
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
      await ref.read(sharePdfProvider).call(
            filePath: filePath,
            displayName: displayName,
            sharePositionOrigin: sharePositionOrigin,
          );
      if (mounted) {
        showAppSnackbar(
            context, l10n?.pdfShareSuccess ?? 'PDF pronto para compartilhar');
      }
    } on Object {
      if (mounted) {
        showAppSnackbar(context,
            l10n?.pdfActionError ?? 'Não foi possível concluir a ação');
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
      final louvor = findLouvorByPdfId(
        ref.read(louvoresManifestProvider).value?.louvores,
        pdfId,
      );
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

      final location = ref.read(openPdfInReaderProvider).call(
            pdfPath: source.absolutePath,
            pdfId: louvor.pdfId,
            titulo: louvor.nome,
          );
      context.replace(location);
    } on PdfOfflineUnavailableException catch (e) {
      if (mounted) {
        showPdfOfflineUnavailableSnackbar(context, message: e.message);
      }
    } on PdfExternallyDeletedException catch (e) {
      if (mounted) {
        showPdfOfflineUnavailableSnackbar(context, message: e.message);
      }
    } on PdfFetchFailedException catch (e) {
      if (mounted) showAppSnackbar(context, e.message);
    } on Object {
      if (mounted) {
        showAppSnackbar(
          context,
          l10n?.pdfActionError ?? 'Não foi possível concluir a ação',
        );
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

    if (filePath.trim().isEmpty) {
      return _ReaderScaffold(
        titulo: titulo,
        showTitle: true,
        body: const _ReaderMessage(
          message: 'Parâmetro file ausente na URL',
        ),
      );
    }

    final isFullscreen = ref.watch(readerFullscreenProvider);

    if (pdfId.isNotEmpty) {
      ref.watch(
        readerAdjacentPdfPrefetchProvider(
          ReaderAdjacentPdfPrefetchParams(
            filePath: filePath,
            pdfId: pdfId,
          ),
        ),
      );
    }

    final sessionAsync = ref.watch(pdfReaderSessionProvider(filePath));

    ref.listen(pdfReaderSessionProvider(filePath), (previous, next) {
      next.whenData((session) {
        if (_appliedFitForPath == session.filePath) return;
        _appliedFitForPath = session.filePath;
        _scheduleApplyInitialFit(session.controller);
      });
    });

    ref.listen(readerFullscreenProvider, (previous, next) {
      if (previous == next) return;
      final session = ref.read(pdfReaderSessionProvider(filePath)).valueOrNull;
      if (session == null) return;
      _scheduleApplyInitialFit(session.controller);
    });

    final sessionLoaded = sessionAsync.maybeWhen(
      data: (_) => true,
      orElse: () => false,
    );
    final sessionLoading = sessionAsync.isLoading;

    return _ReaderScaffold(
      titulo: titulo,
      showTitle: sessionLoading,
      isFullscreen: isFullscreen,
      filePath: sessionLoaded ? filePath : null,
      onToggleFullscreen: () => ref.read(toggleReaderFullscreenProvider).call(),
      onShare: sessionLoaded
          ? (origin) => _sharePdf(filePath, titulo, sharePositionOrigin: origin)
          : null,
      shareLoading: _shareLoading,
      shareTooltip: l10n?.sharePdf ?? 'Compartilhar',
      body: sessionAsync.when(
        loading: () => const PdfPageSkeleton(),
        error: (error, _) {
          if (error is PdfLocalCorruptedException) {
            return _ReaderMessage(
              message: pdfReaderErrorMessage(error),
              retryLabel: _redownloadLoading ? null : 'Baixar novamente',
              onRetry: _redownloadLoading
                  ? null
                  : () => _redownloadCorruptedPdf(error.pdfId),
            );
          }
          if (error is PdfOfflineUnavailableException ||
              error is PdfExternallyDeletedException) {
            return _ReaderMessage(
              message: pdfReaderErrorMessage(error),
              retryLabel: l10n?.pdfOfflineGoToSettings ?? 'Baixar',
              onRetry: () => context.push(RoutePaths.offline),
            );
          }
          return _ReaderMessage(
            message: pdfReaderErrorMessage(error),
            onRetry: () => ref.invalidate(pdfReaderSessionProvider(filePath)),
          );
        },
        data: (session) => PdfxPdfView(
          controller: session.controller,
          navigateToPage: (pageNumber) => ref
              .read(pdfReaderDisplayedPageProvider(filePath).notifier)
              .animateToPage(pageNumber: pageNumber),
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
/// `page/total` navega para a primeira página; valor congelado durante animação.
class _ReaderScaffold extends StatelessWidget {
  const _ReaderScaffold({
    required this.titulo,
    required this.showTitle,
    required this.body,
    this.isFullscreen = false,
    this.filePath,
    this.onToggleFullscreen,
    this.onShare,
    this.shareLoading = false,
    this.shareTooltip,
  });

  final String titulo;
  final bool showTitle;
  final bool isFullscreen;
  final Widget body;
  final String? filePath;
  final VoidCallback? onToggleFullscreen;
  final void Function(Rect? sharePositionOrigin)? onShare;
  final bool shareLoading;
  final String? shareTooltip;

  @override
  Widget build(BuildContext context) {
    final pdfArea = ColoredBox(
      color: AppColors.pdfArea,
      child: body,
    );

    return Column(
      children: [
        if (!isFullscreen)
          SizedBox(
            height: kToolbarHeight,
            child: AppBar(
              primary: false,
              toolbarHeight: kToolbarHeight,
              title: showTitle
                  ? Text(
                      titulo,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              actions: [
                if (onShare != null)
                  Builder(
                    builder: (buttonContext) {
                      return IconButton(
                        tooltip: shareTooltip,
                        onPressed: shareLoading
                            ? null
                            : () => onShare!(
                                  sharePositionOriginFromContext(buttonContext),
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
                if (onToggleFullscreen != null)
                  IconButton(
                    tooltip: 'Tela cheia',
                    icon: const Icon(Icons.fullscreen),
                    onPressed: onToggleFullscreen,
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
                  bottom: 16,
                  child: Opacity(
                    opacity: 0.25,
                    child: FloatingActionButton(
                      tooltip: 'Sair da tela cheia',
                      elevation: 0,
                      highlightElevation: 0,
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      onPressed: onToggleFullscreen,
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
              FilledButton(
                onPressed: onRetry,
                child: Text(retryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
