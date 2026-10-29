import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../../../playlists/domain/entities/playlist_entry.dart';
import '../entities/leaflet_document.dart';
import '../entities/leaflet_entry.dart';
import '../exceptions/empty_leaflet_exception.dart';

/// UC-08 — Folheto a partir das entradas (tipadas) de uma lista, com áudio.
///
/// Substitui `GenerateLeafletFromPdfIds` e `GenerateLeafletFromSelection`: as
/// duas listas (playlist salva e seleção/carousel) chegam já resolvidas em
/// [PlaylistEntry] por quem chama — este use case não sabe mais de onde
/// vieram, só sabe rotulá-las e deduplicar.
///
/// O [lookup] é lido a cada chamada (não capturado no construtor) para que o
/// use case continue síncrono como hoje, mesmo vivendo atrás de um provider
/// Riverpod que só resolve `CatalogMaterialLookup` sob demanda.
class GenerateLeafletFromEntries {
  GenerateLeafletFromEntries({required this.lookup});

  /// Lido a cada [call] — ver docstring da classe.
  final CatalogMaterialLookup Function() lookup;

  /// Lança [EmptyLeafletException] se [entries] vazio.
  ///
  /// Cada entrada é resolvida contra o catálogo (cifra, depois louvor, depois
  /// faixa de áudio); sem hit, o id vira o nome e o número fica vazio
  /// (comportamento atual). Entradas do mesmo `groupId` viram uma linha só —
  /// a primeira ocorrência decide número/nome/posição; sem hit, o próprio id
  /// é a chave de dedupe (não colide com outro id sem hit).
  LeafletDocument call({
    required List<PlaylistEntry> entries,
    required DateTime now,
    String? shareUrl,
  }) {
    if (entries.isEmpty) {
      throw const EmptyLeafletException();
    }

    final catalogLookup = lookup();
    final seenKeys = <String>{};
    final leafletEntries = <LeafletEntry>[];

    for (final entry in entries) {
      final resolved = _resolve(entry.id, catalogLookup);
      final dedupeKey = resolved?.groupId ?? entry.id;
      if (!seenKeys.add(dedupeKey)) continue;

      leafletEntries.add(
        LeafletEntry(
          index: leafletEntries.length + 1,
          numero: resolved?.numero ?? '',
          nome: resolved?.nome ?? entry.id,
        ),
      );
    }

    return LeafletDocument(
      generatedAt: now,
      entries: leafletEntries,
      shareUrl: shareUrl,
    );
  }

  /// Cifra antes de louvor (mais específica — dividem o espaço de ids),
  /// depois faixa de áudio (espaço de ids à parte).
  ({String numero, String nome, String groupId})? _resolve(
    String materialId,
    CatalogMaterialLookup lookup,
  ) {
    final chord = lookup.chord(materialId);
    if (chord != null) {
      return (numero: chord.numero, nome: chord.nome, groupId: chord.groupId);
    }
    final louvor = lookup.louvor(materialId);
    if (louvor != null) {
      return (
        numero: louvor.numero,
        nome: louvor.nome,
        groupId: louvor.effectiveGroupId,
      );
    }
    final audioTrack = lookup.audioTrack(materialId);
    if (audioTrack != null) {
      return (
        numero: audioTrack.numero,
        nome: audioTrack.nome,
        groupId: audioTrack.groupId,
      );
    }
    return null;
  }
}
