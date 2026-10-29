import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/reading_navigation.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/utils/material_id_kind.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../audio_player/presentation/utils/active_list_audio_queue.dart';
import '../../../audio_player/presentation/utils/open_audio_in_player.dart';
import '../../../catalog/domain/entities/catalog_material.dart';
import '../../../catalog/domain/entities/louvor_group.dart';
import '../../../catalog/domain/usecases/cluster_member_label.dart';
import '../../../catalog/domain/usecases/cluster_member_order.dart';
import '../../../coldigom/domain/search/coldigom_search_index.dart';
import '../../../playlists/domain/entities/playlist_entry.dart';
import '../../../playlists/presentation/providers/active_playlist_editor.dart';
import '../providers/carousel_focused_index_provider.dart';
import '../providers/carousel_items_provider.dart';
import 'open_carousel_pdf_in_reader.dart';

/// Retorna a lista de praises relacionados a [group] (mesmo `group_id` no
/// coldigom) a partir do índice [index].
///
/// Retorna vazio se [group] não pertence a um grupo ou se o grupo tem menos de
/// 2 membros.
List<LouvorGroup> resolveRelatedPraisesForGroup(
  LouvorGroup group,
  ColdigomSearchIndex index,
) {
  final praiseGroupKey = praiseGroupKeyOf(group);
  if (praiseGroupKey == null || praiseGroupKey.isEmpty) {
    return const [];
  }
  final members = index.membersOf(praiseGroupKey);
  return members.length > 1 ? members : const [];
}

/// Encontra o material em [targetGroup] que melhor corresponde a [preferredKind].
///
/// Prioriza o mesmo tipo do material atual (cifra → cifra, áudio → áudio,
/// etc.). Se não houver correspondente do mesmo tipo, aplica fallback para o
/// primeiro PDF (partitura), depois cifra, áudio, gestos ou qualquer material.
CatalogMaterial? resolveMatchingMaterialForPraise({
  required LouvorGroup targetGroup,
  required MaterialKind? preferredKind,
}) {
  if (preferredKind != null) {
    switch (preferredKind) {
      case MaterialKind.audio:
        if (targetGroup.audioTracks.isNotEmpty) {
          return AudioMaterial(targetGroup.audioTracks.first);
        }
      case MaterialKind.chord:
        if (targetGroup.chordMaterials.isNotEmpty) {
          return ChordMaterialRef(targetGroup.chordMaterials.first);
        }
      case MaterialKind.gesture:
        if (targetGroup.gestureMaterials.isNotEmpty) {
          return GestureMaterialRef(targetGroup.gestureMaterials.first);
        }
      case MaterialKind.pdf:
        for (final section in targetGroup.sections) {
          if (section.materials.isNotEmpty) {
            return PdfMaterial(section.materials.first.louvor);
          }
        }
      case MaterialKind.lyrics:
        if (targetGroup.lyrics != null) {
          return targetGroup.lyrics;
        }
      case MaterialKind.youtube:
        if (targetGroup.youtubeMaterials.isNotEmpty) {
          return YoutubeMaterialRef(targetGroup.youtubeMaterials.first);
        }
      case MaterialKind.unknown:
        break;
    }
  }

  // Fallbacks em ordem de preferência de leitura
  for (final section in targetGroup.sections) {
    if (section.materials.isNotEmpty) {
      return PdfMaterial(section.materials.first.louvor);
    }
  }
  if (targetGroup.chordMaterials.isNotEmpty) {
    return ChordMaterialRef(targetGroup.chordMaterials.first);
  }
  if (targetGroup.audioTracks.isNotEmpty) {
    return AudioMaterial(targetGroup.audioTracks.first);
  }
  if (targetGroup.gestureMaterials.isNotEmpty) {
    return GestureMaterialRef(targetGroup.gestureMaterials.first);
  }
  if (targetGroup.materials.isNotEmpty) {
    return targetGroup.materials.first;
  }
  return null;
}

/// Chave da primeira ocorrência de [materialId] na lista ativa.
String? _keyForMaterialId(WidgetRef ref, String materialId) {
  for (final item in ref.read(carouselItemsProvider)) {
    if (item.materialId == materialId) return item.key;
  }
  return null;
}

/// Alterna para a versão [targetGroup] do mesmo louvor:
/// 1. Substitui a ocorrência [currentEntryKey] na playlist ativa por [replaceByKey];
/// 2. Atualiza o leitor ou player caso o usuário esteja em uma tela de leitura/reprodução;
/// 3. Fornece feedback tátil e snackbar;
/// 4. Foca a nova entrada no carrossel.
Future<void> swapToRelatedPraise({
  required WidgetRef ref,
  required BuildContext context,
  required LouvorGroup targetGroup,
  required String currentEntryKey,
  String? currentMaterialId,
  List<LouvorGroup>? allMembers,
}) async {
  final currentKind =
      currentMaterialId != null && currentMaterialId.isNotEmpty
          ? materialIdKindOf(currentMaterialId)
          : null;

  final matching = resolveMatchingMaterialForPraise(
    targetGroup: targetGroup,
    preferredKind: currentKind,
  );
  if (matching == null) return;

  // 1. Substitui na lista ativa
  await ref
      .read(activePlaylistEditorProvider.notifier)
      .replaceByKey(
        currentEntryKey,
        PlaylistEntry(id: matching.id, kind: matching.kind),
      );

  if (!context.mounted) return;

  // 2. Feedback tátil e snackbar
  unawaited(HapticFeedback.lightImpact());
  final tag =
      (allMembers != null ? clusterMemberLabel(targetGroup, allMembers) : null) ??
      targetGroup.coldigomMeta?.tagNames.firstOrNull ??
      targetGroup.numero;

  final l10n = AppLocalizations.of(context);
  final message =
      l10n != null ? l10n.relatedPraisesSwapped(tag) : 'Versão trocada: $tag';
  showAppSnackbar(context, message, clearPrevious: true);

  // 3. Atualiza leitura ou player se estiver na tela
  String? path;
  try {
    path = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
  } catch (_) {
    try {
      path = GoRouterState.of(context).uri.path;
    } catch (_) {
      path = null;
    }
  }
  final onReader =
      path == RoutePaths.reader ||
      path == RoutePaths.chords ||
      path == RoutePaths.gestos;

  if (onReader) {
    await openCarouselPdfInReader(
      ref: ref,
      context: context,
      materialId: matching.id,
      navigate: (location) async => openReadingLocation(context, location),
    );
  } else if (matching is AudioMaterial) {
    await playAudioInSession(
      ref: ref,
      track: matching.track,
      queue: queueForTrack(
        track: matching.track,
        groupTracks: targetGroup.audioTracks,
        activeQueue: activeListAudioQueue(ref),
      ),
    );
  }

  if (!context.mounted) return;
  final focusedKey = _keyForMaterialId(ref, matching.id);
  if (focusedKey != null) {
    ref.read(carouselFocusedIndexProvider.notifier).focusKey(focusedKey);
  }
}
