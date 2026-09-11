import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../providers/active_playlist_editor.dart';
import '../providers/playlists_provider.dart';

/// Coluna de chips (um por PDF/cifra na face de partituras) do
/// [PlaylistListTile] expandido — toque abre no leitor, «×» remove a
/// ocorrência.
///
/// Extraído de `playlist_list_tile.dart` (E4) — sem mudança de comportamento.
class PlaylistTileDetailChips extends ConsumerWidget {
  const PlaylistTileDetailChips({
    required this.item,
    required this.loading,
    required this.onPdfTap,
    super.key,
  });

  final PlaylistViewItem item;
  final bool loading;
  final Future<void> Function(String pdfId) onPdfTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Face de partituras com posição na ordem única e chave por ocorrência:
    // o «×» remove **aquela** ocorrência (B.1), e a chave dá identidade ao
    // chip quando a lista repete um louvor.
    final face = <ActiveEntry>[
      for (final entry in activeEntriesOf(item.playlist.entries))
        if (!entry.isAudio) entry,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < face.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            CarouselLouvorChip(
              key: ValueKey(face[i].key),
              item: _carouselItemFor(
                entry: face[i],
                // `pdfLabels` é a projeção desta mesma face, na mesma ordem.
                label: item.pdfLabels[i],
                faceIndex: i,
                findLouvor: ref.read(catalogMaterialLookupProvider).louvor,
              ),
              onTap: loading ? null : () => onPdfTap(face[i].id),
              onRemove: loading
                  ? null
                  : () async {
                      if (face.length == 1) {
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
                            index: face[i].index,
                          );
                    },
            ),
          ],
        ],
      ),
    );
  }

  /// Item do chip para [entry], com a chave da ocorrência e o índice na face.
  static CarouselItem _carouselItemFor({
    required ActiveEntry entry,
    required String label,
    required int faceIndex,
    required Louvor? Function(String pdfId) findLouvor,
  }) {
    final pdfId = entry.id;
    final louvor = findLouvor(pdfId);
    if (louvor != null) {
      return CarouselItem(
        materialId: pdfId,
        kind: entry.kind,
        index: faceIndex,
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
        index: faceIndex,
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
      index: faceIndex,
      key: entry.key,
      numero: '',
      nome: label,
      categoria: '',
      classificacao: '',
      source: inferredSource,
    );
  }
}
