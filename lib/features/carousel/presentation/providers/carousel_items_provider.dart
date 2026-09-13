import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/pdf_id_codec.dart';
import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../../../playlists/presentation/providers/active_playlist_editor.dart';
import '../../domain/entities/carousel_item.dart';
import 'carousel_focused_index_provider.dart';

/// Face de partituras da lista ativa (tudo que **não** é áudio), enriquecida.
///
/// Derivação pura de `activeEntriesProvider` + o lookup síncrono por id
/// (manifest PLPCG e caches Coldigom) — A4: nenhum mapa O(catálogo) por
/// mutação; o carousel não tem estado próprio (D3).
final carouselItemsProvider = Provider<List<CarouselItem>>((ref) {
  return _faceItems(ref, audio: false);
});

/// Face de áudio da lista ativa.
final audioFaceItemsProvider = Provider<List<CarouselItem>>((ref) {
  return _faceItems(ref, audio: true);
});

/// Ids presentes na lista ativa, em **qualquer** face — membership O(1).
///
/// Consumido pelo badge «já está na lista» dos cards (via `select`).
final activeMaterialIdsProvider = Provider<Set<String>>((ref) {
  final entries = ref.watch(activeEntriesProvider);
  return {for (final entry in entries) entry.id};
});

/// Item focado na face de partituras, ou `null` se a face estiver vazia.
final focusedCarouselItemProvider = Provider<CarouselItem?>((ref) {
  final items = ref.watch(carouselItemsProvider);
  if (items.isEmpty) return null;
  final index = ref.watch(carouselFocusedIndexProvider);
  if (index < 0 || index >= items.length) return null;
  return items[index];
});

List<CarouselItem> _faceItems(Ref ref, {required bool audio}) {
  final entries = ref.watch(activeEntriesProvider);
  final lookup = ref.watch(catalogMaterialLookupProvider);

  final items = <CarouselItem>[];
  for (final entry in entries) {
    if (entry.isAudio != audio) continue;
    items.add(_enrich(entry, items.length, lookup));
  }
  return List<CarouselItem>.unmodifiable(items);
}

/// Precedência dos metadados: cifra/gesto antes de PDF — os três dividem o
/// espaço de ids, e um material em cache é a resposta mais específica.
CarouselItem _enrich(
  ActiveEntry entry,
  int faceIndex,
  CatalogMaterialLookup lookup,
) {
  final chord = lookup.chord(entry.id);
  if (chord != null) {
    return CarouselItem(
      materialId: entry.id,
      kind: entry.kind,
      index: faceIndex,
      key: entry.key,
      numero: chord.numero,
      nome: chord.nome,
      categoria: chord.categoria,
      classificacao: chord.classificacao,
      source: chord.source,
    );
  }

  final gesture = lookup.gesture(entry.id);
  if (gesture != null) {
    return CarouselItem(
      materialId: entry.id,
      kind: entry.kind,
      index: faceIndex,
      key: entry.key,
      numero: gesture.numero,
      nome: gesture.nome,
      categoria: gesture.categoria,
      classificacao: gesture.classificacao,
      source: gesture.source,
    );
  }

  final louvor = lookup.louvor(entry.id);
  if (louvor != null) {
    return CarouselItem(
      materialId: entry.id,
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

  return CarouselItem(
    materialId: entry.id,
    kind: entry.kind,
    index: faceIndex,
    key: entry.key,
    numero: '',
    nome: fallbackCarouselNome(entry.id),
    categoria: '',
    classificacao: '',
    source: louvorDataSourceFromPdfId(entry.id),
  );
}

/// Fallback quando o id não está no manifest nem nos caches.
String fallbackCarouselNome(String materialId) {
  if (materialId.length <= 12) return materialId;
  return '${materialId.substring(0, 12)}…';
}
