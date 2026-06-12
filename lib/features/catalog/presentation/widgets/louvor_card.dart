import 'package:coldigui/core/widgets/app_snackbar.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/offline/data/providers/offline_providers.dart';
import 'package:coldigui/features/offline/domain/entities/local_pdf_source.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/pdf_opening/data/providers/pdf_opening_providers.dart';
import 'package:coldigui/features/pdf_opening/domain/utils/louvor_pdf_path.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/invalid_pdf_path_exception.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/louvor.dart';

/// Item de louvor em lista — UC-01, UC-03, UC-04, UC-05.
///
/// Wrapper compartilhado de [CarouselLouvorChip] (variante [CarouselLouvorChipVariant.modal])
/// para [HomeScreen] (pesquisa) e [LibraryScreen] (biblioteca). Converte [Louvor]
/// em [CarouselItem]; observa [carouselLouvoresProvider] para estado adicionado.
///
/// - **Toque no corpo:** resolve PDF e abre no leitor interno (`/leitor`).
/// - **Trailing +:** [carouselLouvoresProvider.notifier.add] (UC-05).
/// - **Trailing ✓:** louvor já na seleção.
/// - **Menu ⋮:** compartilhar PDF (UC-04) via [sharePdfProvider] — paridade
///   com [PdfReaderScreen]; âncora iOS via [sharePositionOriginFromContextOrFallback].
/// - **[loading]:** spinner no trailing durante resolve/navegação PDF.
/// - **[shareLoading]:** spinner no ícone ⋮ durante compartilhamento.
class LouvorCard extends ConsumerStatefulWidget {
  const LouvorCard({required this.louvor, super.key});

  /// Louvor a renderizar; tipicamente vindo do manifest ou cache Isar.
  final Louvor louvor;

  @override
  ConsumerState<LouvorCard> createState() => _LouvorCardState();
}

class _LouvorCardState extends ConsumerState<LouvorCard> {
  var _loading = false;
  var _shareLoading = false;

  Future<LocalPdfSource> _resolvePdf() {
    final remotePath = LouvorPdfPath.fromLouvor(widget.louvor);
    return ref.read(resolvePdfForReaderProvider)(
      pdfId: widget.louvor.pdfId,
      remotePath: remotePath,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    showAppSnackbar(context, message);
  }

  Future<void> _handleTap() async {
    if (_loading) return;

    final l10n = AppLocalizations.of(context)!;

    setState(() => _loading = true);

    try {
      final source = await _resolvePdf();

      if (!mounted) return;

      await ref
          .read(playlistsProvider.notifier)
          .ensurePlaylistForLouvor(widget.louvor.pdfId);
      if (!mounted) return;
      final location = ref.read(openPdfInReaderProvider).call(
            pdfPath: source.absolutePath,
            pdfId: widget.louvor.pdfId,
            titulo: widget.louvor.nome,
          );
      await context.push(location);
    } on InvalidPdfPathException {
      _showError(l10n.pdfActionError);
    } on PdfOfflineUnavailableException catch (e) {
      _showError(e.message);
    } on PdfExternallyDeletedException catch (e) {
      _showError(e.message);
    } on PdfFetchFailedException catch (e) {
      _showError(e.message);
    } on Object {
      _showError(l10n.pdfActionError);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleShare(Rect sharePositionOrigin) async {
    if (_shareLoading || _loading) return;

    final l10n = AppLocalizations.of(context)!;

    setState(() => _shareLoading = true);

    try {
      final source = await _resolvePdf();

      if (!mounted) return;

      await ref.read(sharePdfProvider).call(
            filePath: source.absolutePath,
            displayName: widget.louvor.nome,
            sharePositionOrigin: sharePositionOrigin,
          );

      if (mounted) {
        showAppSnackbar(context, l10n.pdfShareSuccess);
      }
    } on InvalidPdfPathException {
      _showError(l10n.pdfActionError);
    } on PdfOfflineUnavailableException catch (e) {
      _showError(e.message);
    } on PdfExternallyDeletedException catch (e) {
      _showError(e.message);
    } on PdfFetchFailedException catch (e) {
      _showError(e.message);
    } on Object {
      _showError(l10n.pdfActionError);
    } finally {
      if (mounted) {
        setState(() => _shareLoading = false);
      }
    }
  }

  Future<void> _handleAddToCarousel() async {
    final l10n = AppLocalizations.of(context)!;
    final added = await ref
        .read(playlistsProvider.notifier)
        .addLouvorToActivePlaylist(widget.louvor.pdfId);

    if (!mounted) return;
    showAppSnackbar(
      context,
      added ? l10n.carouselAdded : l10n.carouselAlreadyAdded,
    );
  }

  CarouselItem _toCarouselItem() {
    return CarouselItem(
      pdfId: widget.louvor.pdfId,
      sortOrder: 0,
      numero: widget.louvor.numero,
      nome: widget.louvor.nome,
      categoria: widget.louvor.categoria,
      classificacao: widget.louvor.classificacao,
    );
  }

  @override
  Widget build(BuildContext context) {
    final carouselItems = ref.watch(carouselLouvoresProvider);
    final isAdded =
        carouselItems.any((item) => item.pdfId == widget.louvor.pdfId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CarouselLouvorChip(
        item: _toCarouselItem(),
        onTap: _loading ? null : _handleTap,
        onAdd: _loading || isAdded ? null : _handleAddToCarousel,
        onShare: _loading ? null : _handleShare,
        isAdded: isAdded,
        loading: _loading,
        shareLoading: _shareLoading,
      ),
    );
  }
}
