import 'dart:async';

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
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvor_pdf_download_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvor_pdf_download_state.dart';
import 'package:coldigui/features/catalog/presentation/providers/open_material_provider.dart';
import 'package:coldigui/features/catalog/presentation/utils/open_louvor_in_reader.dart';
import 'package:coldigui/features/catalog/presentation/utils/preferred_material_for_group.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet_actions.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/offline/presentation/providers/material_availability_map_provider.dart';
import 'package:coldigui/features/offline/presentation/utils/pdf_offline_error_ui.dart';
import 'package:coldigui/features/pdf_opening/domain/entities/pdf_offline_availability.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Card agrupado na Home/Biblioteca — um louvor lógico, vários materiais.
///
/// Tap: sublista se [LouvorGroup.totalMaterials] > 1; senão abre PDF/áudio direto.
/// Trailing +: adiciona ao carousel só com 1 PDF; com vários, + fica no sheet.
/// Long press: abre direto o material favorito do grupo (mesma resolução
/// do "+"); sem favorito adicionável, cai no mesmo caminho do tap.
class LouvorGroupCard extends ConsumerStatefulWidget {
  const LouvorGroupCard({required this.group, this.isNew = false, super.key});

  final LouvorGroup group;

  /// Card vindo só da validação remota — chip «novo» (§6.3).
  final bool isNew;

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
    await _openMaterialSheet();
  }

  /// Grupo com metadados Coldigom anexados — insumo do `MaterialSheet`.
  LouvorGroup get _resolvedGroup =>
      ref.read(catalogMaterialLookupProvider).withPraiseMeta(widget.group);

  /// Abre o sheet padrão (abre o material tocado, sem trocar a lista ativa).
  ///
  /// Reaberto tanto pelo tap no corpo do card (multi-material) quanto pelo
  /// toque num ícone de `MaterialKindsRow` (C5).
  Future<void> _openMaterialSheet() async {
    await showMaterialSheet(context, ref, _resolvedGroup);
  }

  /// Pressionar e segurar o card: com favorito disponível — [preferredMaterial],
  /// o mesmo resolvido pelo "+" — abre-o direto, sem passar pelo sheet.
  ///
  /// Sem favorito adicionável (ex.: grupo só com YouTube), cai no mesmo
  /// caminho do [_handleTap] de hoje — nada muda para esses casos.
  Future<void> _handleLongPress(CatalogMaterial? preferredMaterial) async {
    if (preferredMaterial == null) {
      await _handleTap();
      return;
    }
    await ref
        .read(openMaterialProvider)
        .open(
          context,
          ref,
          preferredMaterial,
          audioQueue: widget.group.audioTracks,
        );
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

  /// "+" sempre visível (C5): adiciona [material] — já resolvido por
  /// [preferredMaterialForGroup] — e mostra «Adicionado à lista» com a ação
  /// «Trocar material», que reabre o sheet no fluxo de troca (`replaceByKey`
  /// da entrada recém-criada).
  Future<void> _handleAddPreferredMaterial(CatalogMaterial material) async {
    final l10n = AppLocalizations.of(context)!;
    final outcome = await ref
        .read(activePlaylistEditorProvider.notifier)
        .addToActive(material.id, kind: material.kind);

    if (!mounted) return;

    if (outcome == AddToActiveOutcome.storageUnavailable) {
      showAppSnackbar(context, l10n.playlistStorageUnavailable);
      return;
    }

    // `addToActive` devolve só o desfecho (added/alreadyPresent), não a
    // chave da entrada — a última ocorrência do id na lista ativa é a que
    // acabou de entrar (added) ou a que já estava lá (alreadyPresent), e em
    // ambos os casos é a que faz sentido trocar.
    final key = _lastActiveKeyFor(material.id);
    // alreadyPresent não é "adicionado" — mesma mensagem que o caminho de
    // material único (`addMaterialToActivePlaylist`) usa para o mesmo
    // desfecho; a ação de trocar continua valendo (a entrada já existe).
    final message = outcome == AddToActiveOutcome.alreadyPresent
        ? l10n.carouselAlreadyAdded
        : l10n.cardAddedSwapMaterial;
    showAppSnackbar(
      context,
      message,
      clearPrevious: true,
      action: key == null
          ? null
          : SnackBarAction(
              label: l10n.cardSwapMaterialAction,
              onPressed: () => unawaited(_openSwapMaterialSheet(key)),
            ),
    );
  }

  /// Chave da última ocorrência de [materialId] na lista ativa.
  String? _lastActiveKeyFor(String materialId) {
    String? key;
    for (final entry in ref.read(activeEntriesProvider)) {
      if (entry.id == materialId) key = entry.key;
    }
    return key;
  }

  /// Sheet no fluxo de troca: PDF/áudio substitui a entrada [key] da lista
  /// ativa em vez de só abrir; cifra/YouTube (sem entrada própria) seguem
  /// abrindo normalmente.
  Future<void> _openSwapMaterialSheet(String key) async {
    final group = _resolvedGroup;
    await showMaterialSheet(
      context,
      ref,
      group,
      canAddToPlaylist: false,
      onMaterialSelected: (material) async {
        if (material is ChordMaterialRef || material is YoutubeMaterialRef) {
          await ref
              .read(openMaterialProvider)
              .open(context, ref, material, audioQueue: group.audioTracks);
          return;
        }
        await ref
            .read(activePlaylistEditorProvider.notifier)
            .replaceByKey(
              key,
              PlaylistEntry(id: material.id, kind: material.kind),
            );
      },
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
    final highlightQuery = ref.watch(homeSearchDebouncedQueryProvider);

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

    // C5: a linha de metadados do card mostra os ícones por tipo de material
    // (`materialKindsGroup` no chip) em vez do resumo textual — a chave
    // `louvorGroupMetadataSummary` fica reservada para o sheet. O progresso
    // de download continua como texto, prioridade sobre os ícones.
    final metadataSummary = _downloadProgressLabel(activeDownload, l10n);

    // C5: "+" sempre visível — primeiro favorito adicionável do grupo
    // (favoriteMaterialKindRankProvider); sem favorito presente, PDF
    // principal, senão o único áudio, senão o primeiro extra adicionável
    // (cifra/YouTube não têm entrada própria). O caminho de um único PDF é
    // preservado à parte para manter o "já adicionado" (✓) e a snackbar
    // genérica do editor.
    final isSinglePdfOnly = !isMultiMaterial && primary != null;
    final favoriteRank = ref.watch(favoriteMaterialKindRankProvider);
    final preferredMaterial = isSinglePdfOnly
        ? null
        : preferredMaterialForGroup(widget.group, rank: favoriteRank);

    // §5.5: o grupo é «disponível» se **algum** material dele está no
    // aparelho — PDF, áudio, cifra ou gestos. Persistente ganha de LRU.
    final materialIds = [for (final m in widget.group.materials) m.id];
    final offlineAvailability = ref.watch(
      materialAvailabilityMapProvider.select((map) {
        var best = PdfOfflineAvailability.notAvailable;
        for (final id in materialIds) {
          final value = map[id];
          // `map[id]` é nulável (`PdfOfflineAvailability?`); o `==` acima não
          // promove o tipo, então devolvemos as constantes, não `value`.
          if (value == PdfOfflineAvailability.persistentOffline) {
            return PdfOfflineAvailability.persistentOffline;
          }
          if (value == PdfOfflineAvailability.cachedLru) {
            best = PdfOfflineAvailability.cachedLru;
          }
        }
        return best;
      }),
    );

    final VoidCallback? onAdd = isLoading
        ? null
        : isSinglePdfOnly
        ? (isAdded ? null : _handleAddToCarousel)
        : (preferredMaterial == null
              ? null
              : () =>
                    unawaited(_handleAddPreferredMaterial(preferredMaterial)));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CarouselLouvorChip(
        item: chipItem,
        metadataSummary: metadataSummary,
        materialKindsGroup: widget.group,
        onMaterialKindTap: (_) => unawaited(_openMaterialSheet()),
        highlightQuery: highlightQuery,
        onTap: isLoading ? null : _handleTap,
        onLongPress: isLoading
            ? null
            : () => unawaited(_handleLongPress(preferredMaterial)),
        onAdd: onAdd,
        isAdded: isMultiMaterial ? false : isAdded,
        loading: isLoading,
        offlineAvailability: offlineAvailability,
        isNew: widget.isNew,
      ),
    );
  }
}
