import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/widgets/app_snackbar.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvor_pdf_download_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvor_pdf_download_state.dart';
import 'package:coldigui/features/catalog/presentation/utils/open_louvor_in_reader.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_material_sheet.dart';
import 'package:coldigui/features/offline/data/providers/offline_providers.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/offline/presentation/utils/pdf_offline_error_ui.dart';
import 'package:coldigui/features/pdf_opening/domain/entities/pdf_offline_availability.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Card agrupado na Home/Biblioteca — um louvor lógico, vários materiais.
///
/// Tap: sublista se [LouvorGroup.totalMaterials] > 1; senão abre PDF direto.
/// Trailing +: adiciona ao carousel só com 1 material; com vários, + fica no sheet.
/// Compartilhar (UC-04): com 1 PDF, só no leitor.
class LouvorGroupCard extends ConsumerStatefulWidget {
  const LouvorGroupCard({required this.group, super.key});

  final LouvorGroup group;

  @override
  ConsumerState<LouvorGroupCard> createState() => _LouvorGroupCardState();
}

class _LouvorGroupCardState extends ConsumerState<LouvorGroupCard> {
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
    final l10n = AppLocalizations.of(context)!;
    try {
      await openLouvorInReader(ref: ref, context: context, louvor: louvor);
    } on PdfOfflineUnavailableException catch (e) {
      if (mounted) {
        showPdfOfflineUnavailableSnackbar(context, message: e.message);
      }
    } on Object catch (e) {
      if (mounted) {
        showAppSnackbar(context, louvorPdfErrorMessage(e, l10n.pdfActionError));
      }
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
      onMaterialAdd: _handleAddMaterialToCarousel,
    );
  }

  Future<void> _handleAddToCarousel() async {
    final louvor = widget.group.primaryLouvor;
    if (louvor == null) return;

    if (!ref.read(isarAvailableProvider)) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        'Armazenamento local indisponível. Listas não podem ser salvas.',
      );
      return;
    }

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

  Future<void> _handleAddMaterialToCarousel(Louvor louvor) async {
    if (!ref.read(isarAvailableProvider)) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        'Armazenamento local indisponível. Listas não podem ser salvas.',
      );
      return;
    }

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

  Set<String> get _groupPdfIds => {
    for (final section in widget.group.sections)
      for (final material in section.materials) material.pdfId,
  };

  String? _downloadProgressLabel(
    LouvorPdfDownloadState? state,
    AppLocalizations l10n,
  ) {
    if (state == null || !state.isLoading) return null;
    if (state.showProgressLabel && state.progressFraction != null) {
      final percent = (state.progressFraction! * 100).round();
      return l10n.louvorPdfDownloadingWithProgress(percent);
    }
    return l10n.louvorPdfDownloading;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pdfIds = _groupPdfIds;
    final activeDownload = ref.watch(
      louvorPdfDownloadProvider.select((states) {
        for (final pdfId in pdfIds) {
          final state = states[pdfId];
          if (state?.isLoading == true) return state;
        }
        return null;
      }),
    );
    final isLoading = activeDownload?.isLoading ?? false;
    final primary = widget.group.primaryLouvor;
    final isAdded = primary != null
        ? ref.watch(
            carouselPdfIdsProvider.select((ids) => ids.contains(primary.pdfId)),
          )
        : false;
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

    final metadataSummary =
        _downloadProgressLabel(activeDownload, l10n) ??
        (isMultiMaterial
            ? l10n.louvorGroupMetadataSummary(
                widget.group.totalMaterials,
                widget.group.totalArrangements,
              )
            : null);

    final offlineAvailability = primary != null
        ? ref.watch(_offlineAvailabilityProvider(primary.pdfId)).value ??
              PdfOfflineAvailability.notAvailable
        : PdfOfflineAvailability.notAvailable;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CarouselLouvorChip(
        item: chipItem,
        metadataSummary: metadataSummary,
        onTap: isLoading ? null : _handleTap,
        onAdd: isLoading || isAdded || primary == null || isMultiMaterial
            ? null
            : _handleAddToCarousel,
        isAdded: isMultiMaterial ? false : isAdded,
        loading: isLoading,
        offlineAvailability: offlineAvailability,
      ),
    );
  }
}

final _offlineAvailabilityProvider = FutureProvider.autoDispose
    .family<PdfOfflineAvailability, String>((ref, pdfId) {
      return ref.watch(validatePdfAvailabilityProvider).call(pdfId: pdfId);
    });
