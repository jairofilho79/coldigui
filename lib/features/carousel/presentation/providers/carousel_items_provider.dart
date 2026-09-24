import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../../../playlists/presentation/providers/active_playlist_editor.dart';
import '../../domain/entities/carousel_item.dart';
import 'carousel_focused_index_provider.dart';

/// Lista ativa inteira, enriquecida — partitura, cifra, gesto e áudio na ordem
/// em que estão na lista (spec 2026-09-12, D1: sem faces).
///
/// Derivação pura de `activeEntriesProvider` + o lookup síncrono por id
/// (catálogo) — A4: nenhum mapa O(catálogo) por
/// mutação; o carousel não tem estado próprio (D3). `index` é a posição na
/// lista inteira, então continua válido nos filtros abaixo.
final carouselItemsProvider = Provider<List<CarouselItem>>((ref) {
  final entries = ref.watch(activeEntriesProvider);
  final lookup = ref.watch(catalogMaterialLookupProvider);
  return List<CarouselItem>.unmodifiable([
    for (final entry in entries) _enrich(entry, lookup),
  ]);
});

/// Só o que se **lê** (tudo menos áudio) — é por aqui que o leitor navega:
/// as setas do leitor pulam áudio, e «seguir o áudio» procura partitura aqui.
final readableCarouselItemsProvider = Provider<List<CarouselItem>>((ref) {
  final items = ref.watch(carouselItemsProvider);
  return List<CarouselItem>.unmodifiable([
    for (final item in items)
      if (!item.isAudio) item,
  ]);
});

/// Só as entradas de áudio — alimenta a fila de reprodução da lista ativa
/// (`activeListAudioQueue`).
final audioCarouselItemsProvider = Provider<List<CarouselItem>>((ref) {
  final items = ref.watch(carouselItemsProvider);
  return List<CarouselItem>.unmodifiable([
    for (final item in items)
      if (item.isAudio) item,
  ]);
});

/// Ids presentes na lista ativa — membership O(1).
///
/// Consumido pelo badge «já está na lista» dos cards (via `select`).
final activeMaterialIdsProvider = Provider<Set<String>>((ref) {
  final entries = ref.watch(activeEntriesProvider);
  return {for (final entry in entries) entry.id};
});

/// Item focado na lista, ou `null` se ela estiver vazia.
final focusedCarouselItemProvider = Provider<CarouselItem?>((ref) {
  final items = ref.watch(carouselItemsProvider);
  if (items.isEmpty) return null;
  final index = ref.watch(carouselFocusedIndexProvider);
  if (index < 0 || index >= items.length) return null;
  return items[index];
});

/// Precedência dos metadados: áudio pelo seu `kind`; cifra/gesto antes de PDF
/// — os três dividem o espaço de ids, e um material em cache é a resposta mais
/// específica.
CarouselItem _enrich(ActiveEntry entry, CatalogMaterialLookup lookup) {
  final index = entry.index;

  if (entry.isAudio) {
    final track = lookup.audioTrack(entry.id);
    if (track != null) {
      return CarouselItem(
        materialId: entry.id,
        kind: entry.kind,
        index: index,
        key: entry.key,
        numero: track.numero,
        nome: track.nome,
        categoria: track.categoria,
        classificacao: track.classificacao,
      );
    }
    return CarouselItem(
      materialId: entry.id,
      kind: entry.kind,
      index: index,
      key: entry.key,
      numero: '',
      nome: fallbackCarouselNome(entry.id),
      categoria: '',
      classificacao: '',
    );
  }

  final chord = lookup.chord(entry.id);
  if (chord != null) {
    return CarouselItem(
      materialId: entry.id,
      kind: entry.kind,
      index: index,
      key: entry.key,
      numero: chord.numero,
      nome: chord.nome,
      categoria: chord.categoria,
      classificacao: chord.classificacao,
    );
  }

  final gesture = lookup.gesture(entry.id);
  if (gesture != null) {
    return CarouselItem(
      materialId: entry.id,
      kind: entry.kind,
      index: index,
      key: entry.key,
      numero: gesture.numero,
      nome: gesture.nome,
      categoria: gesture.categoria,
      classificacao: gesture.classificacao,
    );
  }

  final louvor = lookup.louvor(entry.id);
  if (louvor != null) {
    return CarouselItem(
      materialId: entry.id,
      kind: entry.kind,
      index: index,
      key: entry.key,
      numero: louvor.numero,
      nome: louvor.nome,
      categoria: louvor.categoria,
      classificacao: louvor.classificacao,
    );
  }

  return CarouselItem(
    materialId: entry.id,
    kind: entry.kind,
    index: index,
    key: entry.key,
    numero: '',
    nome: fallbackCarouselNome(entry.id),
    categoria: '',
    classificacao: '',
  );
}

/// Fallback quando o id não está no catálogo coldigom em memória.
String fallbackCarouselNome(String materialId) {
  if (materialId.length <= 12) return materialId;
  return '${materialId.substring(0, 12)}…';
}
