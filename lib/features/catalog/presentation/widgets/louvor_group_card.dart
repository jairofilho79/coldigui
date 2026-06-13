import 'package:coldigui/core/widgets/app_snackbar.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/utils/open_louvor_in_reader.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_material_sheet.dart';
import 'package:coldigui/features/pdf_opening/data/providers/pdf_opening_providers.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Card agrupado na Home/Biblioteca — um louvor lógico, vários materiais.
///
/// Tap: sublista se [LouvorGroup.totalMaterials] > 1; senão abre PDF direto.
/// Trailing +: adiciona material primário (Partitura ou primeiro) ao carousel.
/// Compartilhar (UC-04): no sheet de materiais; com 1 PDF, só no leitor.
class LouvorGroupCard extends ConsumerStatefulWidget {
  const LouvorGroupCard({required this.group, super.key});

  final LouvorGroup group;

  @override
  ConsumerState<LouvorGroupCard> createState() => _LouvorGroupCardState();
}

class _LouvorGroupCardState extends ConsumerState<LouvorGroupCard> {
  var _loading = false;

  Louvor? get _singleLouvor =>
      widget.group.totalMaterials == 1 ? widget.group.primaryLouvor : null;

  CarouselItem _toCarouselItem(Louvor louvor) {
    return CarouselItem(
      pdfId: louvor.pdfId,
      sortOrder: 0,
      numero: widget.group.numero,
      nome: widget.group.nome,
      categoria: louvor.categoria,
      classificacao: louvor.classificacao,
    );
  }

  Future<void> _openLouvor(Louvor louvor) async {
    if (_loading) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _loading = true);
    try {
      await openLouvorInReader(ref: ref, context: context, louvor: louvor);
    } on Object catch (e) {
      if (mounted) {
        showAppSnackbar(context, louvorPdfErrorMessage(e, l10n.pdfActionError));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleTap() async {
    final single = _singleLouvor;
    if (single != null) {
      await _openLouvor(single);
      return;
    }
    await showLouvorMaterialSheet(
      context: context,
      group: widget.group,
      onMaterialSelected: _openLouvor,
      onMaterialShare: _shareLouvor,
    );
  }

  Future<void> _shareLouvor(Louvor louvor, Rect sharePositionOrigin) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final source = await resolveLouvorPdf(ref: ref, louvor: louvor);
      if (!mounted) return;
      await ref.read(sharePdfProvider).call(
            filePath: source.absolutePath,
            displayName: louvor.nome,
            sharePositionOrigin: sharePositionOrigin,
          );
      if (mounted) showAppSnackbar(context, l10n.pdfShareSuccess);
    } on Object catch (e) {
      if (mounted) {
        showAppSnackbar(context, louvorPdfErrorMessage(e, l10n.pdfActionError));
      }
    }
  }

  Future<void> _handleAddToCarousel() async {
    final louvor = widget.group.primaryLouvor;
    if (louvor == null) return;

    final l10n = AppLocalizations.of(context)!;
    final added = await ref
        .read(playlistsProvider.notifier)
        .addLouvorToActivePlaylist(louvor.pdfId);

    if (!mounted) return;
    showAppSnackbar(
      context,
      added ? l10n.carouselAdded : l10n.carouselAlreadyAdded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final carouselItems = ref.watch(carouselLouvoresProvider);
    final primary = widget.group.primaryLouvor;
    final isAdded = primary != null &&
        carouselItems.any((item) => item.pdfId == primary.pdfId);
    final isMultiMaterial = widget.group.totalMaterials > 1;

    final chipItem = primary != null
        ? _toCarouselItem(primary)
        : CarouselItem(
            pdfId: widget.group.groupId,
            sortOrder: 0,
            numero: widget.group.numero,
            nome: widget.group.nome,
            categoria: '',
            classificacao: '',
          );

    final metadataSummary = isMultiMaterial
        ? l10n.louvorGroupMetadataSummary(
            widget.group.totalMaterials,
            widget.group.totalArrangements,
          )
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CarouselLouvorChip(
        item: chipItem,
        metadataSummary: metadataSummary,
        onTap: _loading ? null : _handleTap,
        onAdd: _loading || isAdded || primary == null
            ? null
            : _handleAddToCarousel,
        isAdded: isAdded,
        loading: _loading,
      ),
    );
  }
}
