import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart'
    show fallbackCarouselNome;
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../providers/active_playlist_editor.dart';
import '../providers/playlists_provider.dart';

/// Coluna de chips (um por entrada da lista — partitura, cifra, gesto ou
/// áudio) do [PlaylistListTile] expandido — toque em partitura abre no
/// leitor, toque em áudio abre no reprodutor (D10), «×» remove a ocorrência.
///
/// Extraído de `playlist_list_tile.dart` (E4); a face única para todos os
/// tipos veio da tela sem faces (Task 4, 2026-09-12).
class PlaylistTileDetailChips extends ConsumerWidget {
  const PlaylistTileDetailChips({
    required this.item,
    required this.loading,
    required this.onPdfTap,
    required this.onAudioTap,
    super.key,
  });

  final PlaylistViewItem item;
  final bool loading;
  final Future<void> Function(String pdfId) onPdfTap;

  /// Toque num chip de áudio — abre no reprodutor (spec 2026-09-12, D10).
  final Future<void> Function(AudioTrack track) onAudioTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // `watch` (não `read`): sem isso o chip de uma entrada de áudio ainda não
    // cacheada fica preso no fallback para sempre — não reconstrói quando o
    // cache Coldigom termina de aquecer (Importante #4).
    final lookup = ref.watch(catalogMaterialLookupProvider);
    // Lista inteira, na ordem, com chave por ocorrência: o «×» remove
    // **aquela** ocorrência (B.1). `pdfLabels` é a projeção só das entradas
    // legíveis, então ela anda com um cursor próprio.
    final entries = activeEntriesOf(item.playlist.entries);
    var pdfCursor = 0;

    final chips = <Widget>[];
    for (final entry in entries) {
      // Uma faixa só por entrada de áudio (antes era resolvida duas vezes:
      // uma para o item do chip, outra para o `onTap`).
      final track = entry.isAudio ? lookup.audioTrack(entry.id) : null;
      final CarouselItem chipItem;
      if (entry.isAudio) {
        chipItem = _audioItemFor(entry: entry, track: track);
      } else {
        chipItem = _carouselItemFor(
          entry: entry,
          label: pdfCursor < item.pdfLabels.length
              ? item.pdfLabels[pdfCursor]
              : entry.id,
          findLouvor: lookup.louvor,
        );
        pdfCursor++;
      }
      // Áudio ainda sem faixa em cache: nem nome, nem destino de toque —
      // `loading` empresta o spinner que o chip já tem para outras ações
      // assíncronas como sinal visual, em vez de um chip mudo (Importante
      // #4). Ele some sozinho quando o `watch` acima reconstrói com a faixa.
      final trackPending = entry.isAudio && track == null;

      if (chips.isNotEmpty) chips.add(const SizedBox(height: 8));
      chips.add(
        CarouselLouvorChip(
          key: ValueKey(entry.key),
          item: chipItem,
          loading: loading || trackPending,
          onTap: loading || trackPending
              ? null
              : entry.isAudio
              ? () => onAudioTap(track!)
              : () => onPdfTap(entry.id),
          onRemove: loading
              ? null
              : () async {
                  if (entries.length == 1) {
                    final confirmed = await showConfirmDialog(
                      context: context,
                      title: l10n.playlistDeleteLastPdfTitle,
                      message: l10n.playlistDeleteLastPdfMessage,
                    );
                    if (confirmed != true || !context.mounted) return;
                  }
                  await ref
                      .read(playlistsProvider.notifier)
                      .removeEntryAt(
                        playlistId: item.playlist.playlistId,
                        index: entry.index,
                      );
                },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: chips,
      ),
    );
  }

  static CarouselItem _audioItemFor({
    required ActiveEntry entry,
    required AudioTrack? track,
  }) {
    return CarouselItem(
      materialId: entry.id,
      kind: entry.kind,
      index: entry.index,
      key: entry.key,
      numero: track?.numero ?? '',
      nome: track?.nome ?? fallbackCarouselNome(entry.id),
      categoria: track?.categoria ?? '',
      classificacao: track?.classificacao ?? '',
      source: track?.source ?? louvorDataSourceFromPdfId(entry.id),
    );
  }

  /// Item do chip para [entry], com a chave da ocorrência e a posição dela na
  /// ordem única da lista.
  static CarouselItem _carouselItemFor({
    required ActiveEntry entry,
    required String label,
    required Louvor? Function(String pdfId) findLouvor,
  }) {
    final pdfId = entry.id;
    final louvor = findLouvor(pdfId);
    if (louvor != null) {
      return CarouselItem(
        materialId: pdfId,
        kind: entry.kind,
        index: entry.index,
        key: entry.key,
        numero: louvor.numero,
        nome: louvor.nome,
        categoria: louvor.categoria,
        classificacao: louvor.classificacao,
        source: louvor.source,
      );
    }

    final inferredSource = louvorDataSourceFromPdfId(pdfId);
    final dashIndex = label.indexOf(' — ');
    if (dashIndex > 0) {
      return CarouselItem(
        materialId: pdfId,
        kind: entry.kind,
        index: entry.index,
        key: entry.key,
        numero: label.substring(0, dashIndex).trim(),
        nome: label.substring(dashIndex + 3).trim(),
        categoria: '',
        classificacao: '',
        source: inferredSource,
      );
    }

    return CarouselItem(
      materialId: pdfId,
      kind: entry.kind,
      index: entry.index,
      key: entry.key,
      numero: '',
      nome: label,
      categoria: '',
      classificacao: '',
      source: inferredSource,
    );
  }
}
