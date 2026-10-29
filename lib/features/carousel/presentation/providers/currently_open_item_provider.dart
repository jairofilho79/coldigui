import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/material_id_kind.dart';
import '../../../../core/utils/url_sync_params.dart';
import '../../../audio_player/presentation/providers/audio_player_session_provider.dart';
import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../../../pdf_reader/presentation/providers/reader_route_params_provider.dart';
import '../../domain/entities/carousel_item.dart';
import 'carousel_items_provider.dart';

/// Item do material atualmente aberto/em reprodução, mesmo quando não está
/// na lista ativa.
///
/// Lê de [readerRouteParamsProvider] (quando em `/leitor`, `/cifra`, `/gestos`)
/// ou de [audioPlayerSessionProvider] (quando há faixa de áudio carregada/tocando).
final currentlyOpenItemProvider = Provider<CarouselItem?>((ref) {
  final readerParams = ref.watch(readerRouteParamsProvider);
  final pdfId = readerParams[UrlSyncParams.pdfId];

  final lookup = ref.watch(catalogMaterialLookupProvider);

  if (pdfId != null && pdfId.isNotEmpty) {
    final kind = materialIdKindOf(pdfId);
    final titulo = readerParams[UrlSyncParams.titulo] ?? '';
    final subtitulo = readerParams[UrlSyncParams.subtitulo] ?? '';

    return enrichMaterialToCarouselItem(
      materialId: pdfId,
      kind: kind,
      lookup: lookup,
      fallbackNome: titulo,
      fallbackNumero: subtitulo,
    );
  }

  final currentTrack = ref.watch(
    audioPlayerSessionProvider.select((s) => s.currentTrack),
  );
  if (currentTrack != null) {
    return enrichMaterialToCarouselItem(
      materialId: currentTrack.audioId,
      kind: MaterialKind.audio,
      lookup: lookup,
      fallbackNome: currentTrack.nome,
      fallbackNumero: currentTrack.numero,
    );
  }

  return null;
});

/// `true` quando o material atualmente aberto/em reprodução já pertence à
/// lista ativa (`activePlaylist`).
final isCurrentItemInActivePlaylistProvider = Provider<bool>((ref) {
  final current = ref.watch(currentlyOpenItemProvider);
  if (current == null) return false;
  return ref.watch(activeMaterialIdsProvider).contains(current.materialId);
});
