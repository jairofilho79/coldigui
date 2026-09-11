import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/pdf_id_codec.dart';
import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/presentation/providers/louvores_by_pdf_id_provider.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../../../coldigom/data/providers/coldigom_providers.dart';
import '../../../gestures/domain/entities/gesture_material.dart';
import '../../../playlists/presentation/providers/active_playlist_editor.dart';
import '../../domain/entities/carousel_item.dart';
import 'carousel_focused_index_provider.dart';

/// Face de partituras da lista ativa (tudo que **não** é áudio), enriquecida.
///
/// Substitui o antigo `carouselLouvoresProvider` com estado próprio: agora é
/// uma derivação pura de `activeEntriesProvider` + os mapas por id do manifest
/// e dos caches Coldigom (A4 — nenhum mapa O(catálogo) por mutação).
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
  final plpcg = ref.watch(louvoresByPdfIdProvider);
  final coldigom = ref.watch(coldigomLouvoresCacheProvider);
  final chords = ref.watch(coldigomChordMaterialsCacheProvider);
  final gestures = ref.watch(coldigomGestureMaterialsCacheProvider);

  final items = <CarouselItem>[];
  for (final entry in entries) {
    if (entry.isAudio != audio) continue;
    items.add(
      _enrich(
        entry,
        items.length,
        plpcg: plpcg,
        coldigom: coldigom,
        chords: chords,
        gestures: gestures,
      ),
    );
  }
  return List<CarouselItem>.unmodifiable(items);
}

/// Precedência dos metadados: cifra/gesto > coldigom > manifest PLPCG — a
/// mesma do antigo `buildCarouselMetadataMap` (cada fonte sobrescrevia a
/// anterior).
CarouselItem _enrich(
  ActiveEntry entry,
  int faceIndex, {
  required Map<String, Louvor> plpcg,
  required Map<String, Louvor> coldigom,
  required Map<String, ChordMaterial> chords,
  required Map<String, GestureMaterial> gestures,
}) {
  final chord = chords[entry.id];
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

  final gesture = gestures[entry.id];
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

  final louvor = coldigom[entry.id] ?? plpcg[entry.id];
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
