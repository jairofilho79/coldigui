import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../carousel/domain/entities/carousel_item.dart';
import '../../../carousel/presentation/providers/carousel_items_provider.dart';
import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../../domain/entities/audio_track.dart';

/// Fila do player = a reunião (D4).
///
/// A lista ativa é a reunião que o usuário montou; quando a faixa tocada já
/// está nela, a fila é a lista inteira — tocar um louvor emenda no próximo da
/// reunião em vez de parar no fim do grupo. Uma faixa que **não** está na
/// lista (uma busca solta, um arranjo aberto pelo sheet) continua tocando na
/// fila do grupo, que é o contexto que o usuário tinha à mão.
///
/// Antes desta regra viver num lugar só, cada ponto de play tinha a sua
/// versão — e três dos quatro simplesmente ignoravam a lista ativa.

/// Faixas das entradas de áudio da lista ativa, na ordem.
///
/// Ids sem faixa em cache são pulados: uma lista salva pode citar um áudio
/// ainda não aquecido, e isso não pode furar a fila.
List<AudioTrack> activeListAudioQueue(WidgetRef ref) => _queueFrom(
  ref.read(audioCarouselItemsProvider),
  () => ref.read(catalogMaterialLookupProvider),
);

/// Variante de [activeListAudioQueue] para dentro de um provider.
List<AudioTrack> activeListAudioQueueOf(Ref ref) => _queueFrom(
  ref.read(audioCarouselItemsProvider),
  () => ref.read(catalogMaterialLookupProvider),
);

/// Regra híbrida: [track] está em [activeQueue] → a lista; senão → o grupo.
List<AudioTrack> queueForTrack({
  required AudioTrack track,
  required List<AudioTrack> groupTracks,
  required List<AudioTrack> activeQueue,
}) {
  final inActive = activeQueue.any((t) => t.audioId == track.audioId);
  return inActive ? activeQueue : groupTracks;
}

/// O lookup só é lido quando há o que resolver — sem entradas de áudio a fila
/// é vazia e nenhum cache precisa ser tocado.
List<AudioTrack> _queueFrom(
  List<CarouselItem> audioItems,
  CatalogMaterialLookup Function() lookup,
) {
  if (audioItems.isEmpty) return const [];
  return lookup().tracksFor([for (final item in audioItems) item.materialId]);
}
