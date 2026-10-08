import 'dart:async';

import 'package:coldigui/core/routing/reading_navigation.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/features/audio_player/presentation/utils/active_list_audio_queue.dart';
import 'package:coldigui/features/audio_player/presentation/utils/open_audio_in_player.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/carousel/presentation/utils/open_carousel_pdf_in_reader.dart';
import 'package:coldigui/features/carousel/presentation/utils/playlist_bar_tag_formatter.dart';
import 'package:coldigui/features/carousel/presentation/utils/related_praises_swapper.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_action_button.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/usecases/cluster_member_label.dart';
import 'package:coldigui/features/catalog/domain/usecases/cluster_member_order.dart';
import 'package:coldigui/features/catalog/domain/utils/find_louvor_group_by_pdf_id.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_material_lookup_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/open_material_provider.dart';
import 'package:coldigui/features/catalog/presentation/utils/open_louvor_in_reader.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_catalog_source_provider.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

LouvorGroup? resolveCarouselSwapMaterialGroup(
  WidgetRef ref, {
  String? materialId,
  String? audioId,
}) {
  final source = ref.watch(coldigomCatalogSourceProvider);
  final swapGroup = findSwapMaterialGroup(
    pdfId: materialId,
    audioId: audioId,
    source: source,
  );
  if (swapGroup != null) return swapGroup;

  // Se o louvor tem apenas 1 material mas possui versões relacionadas
  // (mesmo group_id no coldigom com >= 2 membros no índice), ainda deve
  // ser possível exibir o botão para troca de versão e material.
  final playingTrack = (audioId == null || audioId.isEmpty)
      ? null
      : source.audioTracks[audioId];
  final playingGroupId = (playingTrack == null || playingTrack.groupId.isEmpty)
      ? null
      : playingTrack.groupId;

  final materialGroup = (materialId == null || materialId.isEmpty)
      ? null
      : source.findGroupForMaterial(materialId);

  final candidate = materialGroup ??
      (playingGroupId != null ? source.findGroupById(playingGroupId) : null);
  if (candidate != null) {
    final key = praiseGroupKeyOf(candidate);
    if (key != null && source.index.membersOf(key).length > 1) {
      return candidate;
    }
  }
  return null;
}

/// «Material» na barra de playlist — oculto se o louvor não tem material
/// alternativo e nem versões relacionadas.
///
/// [entryKey] é a chave da **ocorrência** cuja entrada será trocada
/// ([ActivePlaylistEditor.replaceByKey]). Quem já tem o item focado na mão (a
/// barra do shell) passa a chave dele; quando só o id da faixa tocando está
/// disponível (o mini-player, fora da lista), a chave é resolvida pela
/// primeira ocorrência do id na lista ativa.
///
/// [group] é opcional: quem já resolveu o grupo (ex.: a barra do shell, para
/// decidir se monta este botão) passa-o pronto e evita resolver duas vezes;
/// sem ele, o botão resolve por conta própria a partir de [materialId]/
/// [audioId] — é o caso dos demais chamadores.
class CarouselSwapMaterialButton extends ConsumerStatefulWidget {
  const CarouselSwapMaterialButton({
    this.materialId,
    this.entryKey,
    this.audioId,
    this.group,
    this.showLabel = true,
    this.barWidth,
    super.key,
  });

  final String? materialId;
  final String? entryKey;
  final String? audioId;
  final LouvorGroup? group;

  /// Legenda sob o ícone (barra larga) — repassado a [CarouselBarActionButton].
  final bool showLabel;

  /// Largura total da barra, usada para adaptar responsivamente o tamanho da
  /// tag da versão.
  final double? barWidth;

  @override
  ConsumerState<CarouselSwapMaterialButton> createState() =>
      _CarouselSwapMaterialButtonState();
}

class _CarouselSwapMaterialButtonState
    extends ConsumerState<CarouselSwapMaterialButton> {
  double _dragDelta = 0;

  @override
  Widget build(BuildContext context) {
    final group =
        widget.group ??
        resolveCarouselSwapMaterialGroup(
          ref,
          materialId: widget.materialId,
          audioId: widget.audioId,
        );
    if (group == null) return const SizedBox.shrink();

    // Uma entrada de áudio focada chega só em `audioId` (spec D1: uma
    // entrada só tem um dos dois ids) — o guard de troca do sheet chaveia em
    // `currentMaterialId` e precisa do id que existir, qualquer que seja.
    final currentMaterialId = widget.materialId ?? widget.audioId;

    final l10n = AppLocalizations.of(context)!;
    final index = ref.watch(coldigomSearchIndexProvider);
    final relatedPraises = resolveRelatedPraisesForGroup(group, index);
    final hasRelated = relatedPraises.length > 1;

    final currentTag = hasRelated
        ? (clusterMemberLabel(group, relatedPraises) ??
            group.coldigomMeta?.tagNames.firstOrNull ??
            (group.numero.isNotEmpty ? '#${group.numero}' : group.nome))
        : null;

    final displayTag = currentTag != null
        ? formatPlaylistBarTag(
            currentTag,
            barWidth: widget.barWidth,
            isCompact: !widget.showLabel,
          )
        : null;

    final effectiveKey =
        widget.entryKey ?? _keyForMaterialId(ref, currentMaterialId ?? '');

    Future<void> cyclePraise({required bool isNext}) async {
      if (!hasRelated || effectiveKey == null) return;
      final currentIndex =
          relatedPraises.indexWhere((g) => g.groupId == group.groupId);
      final targetIndex =
          (currentIndex + (isNext ? 1 : -1) + relatedPraises.length) %
              relatedPraises.length;
      if (targetIndex == currentIndex) return;
      final targetGroup = relatedPraises[targetIndex];
      await swapToRelatedPraise(
        ref: ref,
        context: context,
        targetGroup: targetGroup,
        currentEntryKey: effectiveKey,
        currentMaterialId: currentMaterialId,
        allMembers: relatedPraises,
      );
    }

    final buttonWidget = CarouselBarActionButton(
      icon: Icons.change_circle_outlined,
      label: l10n.carouselMaterial,
      tooltip: hasRelated
          ? '${l10n.readerSwitchMaterial} • ${l10n.readerSwitchPraiseSwipe}'
          : l10n.readerSwitchMaterial,
      showLabel: widget.showLabel,
      onPressed: () => showCarouselSwapMaterialSheet(
        context: context,
        ref: ref,
        group: group,
        currentMaterialId: currentMaterialId,
        currentEntryKey: widget.entryKey,
      ),
    );

    Widget content = buttonWidget;

    if (hasRelated && currentTag != null) {
      if (widget.showLabel) {
        // Modo barra larga: exibe o chip da versão ao lado do botão de material
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CarouselVersionTagChip(
              tag: displayTag ?? currentTag,
              tooltip:
                  '${l10n.relatedPraisesTitle}: $currentTag (${l10n.readerSwitchPraiseSwipe})',
              maxWidth: widget.barWidth != null
                  ? (widget.barWidth! * 0.18).clamp(72.0, 160.0)
                  : 140.0,
              onTap: () => showCarouselSwapMaterialSheet(
                context: context,
                ref: ref,
                group: group,
                currentMaterialId: currentMaterialId,
                currentEntryKey: widget.entryKey,
              ),
              onPrevious: () => cyclePraise(isNext: false),
              onNext: () => cyclePraise(isNext: true),
            ),
            const SizedBox(width: 4),
            buttonWidget,
          ],
        );
      } else {
        // Modo barra estreita: sobrepõe uma badge sutil com o nome da tag
        content = Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            buttonWidget,
            Positioned(
              top: 2,
              right: 2,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 56),
                    child: Text(
                      displayTag ?? currentTag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.card,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: hasRelated ? (_) => _dragDelta = 0 : null,
      onHorizontalDragUpdate: hasRelated
          ? (details) => _dragDelta += details.primaryDelta ?? 0
          : null,
      onHorizontalDragEnd: hasRelated
          ? (details) {
              final velocity = details.primaryVelocity ?? 0;
              final isSwipe = velocity.abs() >= 50;
              final isDrag = _dragDelta.abs() >= 20;
              if (isSwipe || isDrag) {
                final isNext = isSwipe ? velocity < 0 : _dragDelta < 0;
                unawaited(cyclePraise(isNext: isNext));
              }
              _dragDelta = 0;
            }
          : null,
      child: content,
    );
  }
}

Future<void> showCarouselSwapMaterialSheet({
  required BuildContext context,
  required WidgetRef ref,
  required LouvorGroup group,
  String? currentMaterialId,
  String? currentEntryKey,
}) async {
  final resolved = ref
      .read(catalogMaterialLookupProvider)
      .withPraiseMeta(group);

  await showMaterialSheet(
    context,
    ref,
    resolved,
    // O louvor já está na lista: o `+` de cada material não faz sentido aqui.
    canAddToPlaylist: false,
    currentMaterialId: currentMaterialId,
    currentEntryKey: currentEntryKey,
    // O que se lê (PDF, cifra, gestos) **troca** a entrada da lista ativa —
    // é o mesmo louvor com outro material — em vez de empilhar uma rota nova
    // ou entrar no fim da lista; áudio toca sem tirar o usuário da partitura
    // (ouvir enquanto lê); YouTube segue pelo opener único.
    onMaterialSelected: (material) async {
      switch (material) {
        case PdfMaterial() || ChordMaterialRef() || GestureMaterialRef():
          await _onReadableMaterialSelected(
            ref: ref,
            context: context,
            currentMaterialId: currentMaterialId,
            currentEntryKey: currentEntryKey,
            selected: material,
          );
        case AudioMaterial(:final track):
          // A entrada focada já é um áudio: escolher outra voz **troca** a
          // entrada (spec 2026-09-12, §3.2) — o `|◀ ▶|` de dentro do grupo
          // saiu da barra e este é o lugar dele agora.
          if (currentEntryKey != null &&
              currentMaterialId != null &&
              materialIdKindOf(currentMaterialId) == MaterialKind.audio &&
              track.audioId != currentMaterialId) {
            await ref
                .read(activePlaylistEditorProvider.notifier)
                .replaceByKey(
                  currentEntryKey,
                  PlaylistEntry(id: track.audioId, kind: MaterialKind.audio),
                );
          }
          await playAudioInSession(
            ref: ref,
            track: track,
            queue: queueForTrack(
              track: track,
              groupTracks: resolved.audioTracks,
              activeQueue: activeListAudioQueue(ref),
            ),
          );
        case YoutubeMaterialRef() || LyricsMaterial():
          await ref.read(openMaterialProvider).open(context, ref, material);
      }
    },
  );
}

/// Chave da primeira ocorrência de [materialId] na lista ativa.
String? _keyForMaterialId(WidgetRef ref, String materialId) {
  for (final item in ref.read(carouselItemsProvider)) {
    if (item.materialId == materialId) return item.key;
  }
  return null;
}

/// Um material que se lê (PDF, cifra ou gestos) escolhido no sheet de troca.
///
/// A lista obedece ao **louvor**, não ao material: a entrada focada é trocada
/// no lugar (`replaceByKey`) e a rota do leitor é substituída — a cifra e os
/// gestos do mesmo louvor nunca entram como entrada nova no fim da lista.
/// `navigateToPdfId` resolve a rota certa para cada tipo (`/leitor`, `/cifra`,
/// `/gestos`).
Future<void> _onReadableMaterialSelected({
  required WidgetRef ref,
  required BuildContext context,
  required String? currentMaterialId,
  required String? currentEntryKey,
  required CatalogMaterial selected,
}) async {
  if (!context.mounted) return;
  final path = GoRouterState.of(context).uri.path;
  final onReader =
      path == RoutePaths.reader ||
      path == RoutePaths.chords ||
      path == RoutePaths.gestos;

  if (currentMaterialId != null &&
      currentMaterialId.isNotEmpty &&
      selected.id != currentMaterialId) {
    final key = currentEntryKey ?? _keyForMaterialId(ref, currentMaterialId);
    if (key != null) {
      // O `kind` vem do material escolhido (B.4), não da extensão do id.
      await ref
          .read(activePlaylistEditorProvider.notifier)
          .replaceByKey(
            key,
            PlaylistEntry(id: selected.id, kind: selected.kind),
          );
    }
  }

  if (!context.mounted) return;
  if (currentMaterialId == null || currentMaterialId.isEmpty) {
    // Sem entrada focada não há o que trocar: abre como do catálogo
    // (o PDF entra na lista pelo `openLouvorInReader`; cifra/gestos pelo
    // opener único).
    if (selected case PdfMaterial(:final louvor)) {
      await openLouvorInReader(ref: ref, context: context, louvor: louvor);
    } else {
      await ref.read(openMaterialProvider).open(context, ref, selected);
    }
    return;
  }

  if (selected.id == currentMaterialId && onReader) return;

  await openCarouselPdfInReader(
    ref: ref,
    context: context,
    materialId: selected.id,
    navigate: (location) async => openReadingLocation(context, location),
  );
  if (!context.mounted) return;
  final focusedKey = _keyForMaterialId(ref, selected.id);
  if (focusedKey != null) {
    ref.read(carouselFocusedIndexProvider.notifier).focusKey(focusedKey);
  }
}

/// Chip de tag da versão para o grupo «louvor» da barra de navegação.
class _CarouselVersionTagChip extends StatelessWidget {
  const _CarouselVersionTagChip({
    required this.tag,
    required this.onTap,
    this.tooltip,
    this.onPrevious,
    this.onNext,
    this.maxWidth,
  });

  final String tag;
  final VoidCallback onTap;
  final String? tooltip;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      tag,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.label.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.title,
      ),
    );

    final chip = Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.75),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.swap_horiz,
            size: 14,
            color: AppColors.title.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 4),
          if (maxWidth != null)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth!),
              child: textWidget,
            )
          else
            textWidget,
        ],
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: tooltip != null ? Tooltip(message: tooltip!, child: chip) : chip,
    );
  }
}

