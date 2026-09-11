import 'package:coldigui/core/errors/user_message_for.dart';
import 'package:coldigui/core/widgets/app_snackbar.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/utils/active_list_audio_queue.dart';
import 'package:coldigui/features/audio_player/presentation/utils/open_audio_in_player.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_material_lookup_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvor_pdf_download_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvor_pdf_download_state.dart';
import 'package:coldigui/features/catalog/presentation/utils/open_louvor_in_reader.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet_actions.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_availability_map_provider.dart';
import 'package:coldigui/features/offline/presentation/utils/pdf_offline_error_ui.dart';
import 'package:coldigui/features/pdf_opening/domain/entities/pdf_offline_availability.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Card agrupado na Home/Biblioteca — um louvor lógico, vários materiais.
///
/// Tap: sublista se [LouvorGroup.totalMaterials] > 1; senão abre PDF/áudio direto.
/// Trailing +: adiciona ao carousel só com 1 PDF; com vários, + fica no sheet.
class LouvorGroupCard extends ConsumerStatefulWidget {
  const LouvorGroupCard({required this.group, super.key});

  final LouvorGroup group;

  @override
  ConsumerState<LouvorGroupCard> createState() => _LouvorGroupCardState();
}

class _LouvorGroupCardState extends ConsumerState<LouvorGroupCard> {
  /// PDF único (sem áudio/YouTube). YouTube sozinho sempre passa pelo sheet.
  Louvor? get _singleLouvor {
    if (widget.group.totalMaterials != 1) return null;
    return widget.group.primaryLouvor;
  }

  AudioTrack? get _singleAudio {
    if (widget.group.totalMaterials != 1) return null;
    if (widget.group.audioTracks.length != 1) return null;
    return widget.group.audioTracks.first;
  }

  CarouselItem _toCarouselItem(Louvor louvor) {
    return CarouselItem(
      materialId: louvor.pdfId,
      index: 0,
      numero: widget.group.numero,
      nome: widget.group.nome,
      categoria: louvor.categoria,
      classificacao: louvor.classificacao,
      source: louvor.source,
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
        showAppSnackbar(context, louvorPdfErrorMessage(l10n, e));
      }
    }
  }

  Future<void> _openAudio(AudioTrack track) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await openAudioInPlayer(
        ref: ref,
        context: context,
        track: track,
        queue: queueForTrack(
          track: track,
          groupTracks: widget.group.audioTracks,
          activeQueue: activeListAudioQueue(ref),
        ),
      );
    } on Object catch (e) {
      debugPrint('[audio] falha ao abrir ${track.audioId}: $e');
      if (mounted) {
        showAppSnackbar(context, userMessageFor(l10n, e));
      }
    }
  }

  Future<void> _handleTap() async {
    final singleAudio = _singleAudio;
    if (singleAudio != null) {
      await _openAudio(singleAudio);
      return;
    }

    final single = _singleLouvor;
    if (single != null) {
      await _openLouvor(single);
      return;
    }

    // YouTube (mesmo único) sempre via sheet — ícone vermelho e abertura externa.
    final group = ref
        .read(catalogMaterialLookupProvider)
        .withPraiseMeta(widget.group);
    await showMaterialSheet(context, ref, group);
  }

  /// Mesmo caminho do `+` do sheet: o editor decide e a snackbar traduz o
  /// resultado — sem pré-julgar o storage no toque (A8).
  Future<void> _handleAddToCarousel() async {
    final louvor = widget.group.primaryLouvor;
    if (louvor == null) return;

    await addMaterialToActivePlaylist(
      context: context,
      ref: ref,
      material: PdfMaterial(louvor),
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
    final singleAudio = _singleAudio;
    final isAdded = primary != null
        ? ref.watch(
            activeMaterialIdsProvider.select(
              (ids) => ids.contains(primary.pdfId),
            ),
          )
        : false;
    final isMultiMaterial = widget.group.totalMaterials > 1;
    final hasAudio = widget.group.audioTracks.isNotEmpty;

    final chipItem = primary != null
        ? _toCarouselItem(primary)
        : CarouselItem(
            materialId: singleAudio?.audioId ?? widget.group.groupId,
            kind: singleAudio == null
                ? MaterialKind.unknown
                : MaterialKind.audio,
            index: 0,
            numero: widget.group.numero,
            nome: widget.group.nome,
            categoria: hasAudio ? 'Áudio' : '',
            classificacao: singleAudio?.classificacao ?? '',
            source: singleAudio?.source ?? LouvorDataSource.coldigom,
          );

    final metadataSummary =
        _downloadProgressLabel(activeDownload, l10n) ??
        (isMultiMaterial
            ? l10n.louvorGroupMetadataSummary(
                widget.group.totalMaterials,
                widget.group.totalArrangements == 0
                    ? 1
                    : widget.group.totalArrangements,
              )
            : (hasAudio ? l10n.audioMaterialSection : null));

    // A5: um mapa único do índice, lido por `select` — sem query por card.
    final offlineAvailability = primary != null
        ? ref.watch(
            offlineAvailabilityMapProvider.select(
              (map) =>
                  map[primary.pdfId] ?? PdfOfflineAvailability.notAvailable,
            ),
          )
        : PdfOfflineAvailability.notAvailable;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CarouselLouvorChip(
        item: chipItem,
        metadataSummary: metadataSummary,
        onTap: isLoading ? null : _handleTap,
        onAdd:
            isLoading ||
                isAdded ||
                primary == null ||
                isMultiMaterial ||
                singleAudio != null
            ? null
            : _handleAddToCarousel,
        isAdded: isMultiMaterial ? false : isAdded,
        loading: isLoading,
        offlineAvailability: offlineAvailability,
      ),
    );
  }
}
