import 'playlist_entry.dart';

/// Uma entrada da lista ativa **com a sua posição e a sua chave estável**.
///
/// A identidade de uma entrada é a **posição** ([index]) — `entries` pode
/// repetir o mesmo id, e duas ocorrências só se distinguem por onde estão. A
/// [key] é a projeção dessa identidade num `String` que sobrevive a rebuilds:
/// serve a `ValueKey`, ao foco persistido e às mutações por chave do
/// `ActivePlaylistEditor`.
final class ActiveEntry {
  const ActiveEntry({
    required this.index,
    required this.entry,
    required this.key,
  });

  /// Posição em `SavedPlaylist.entries` (ordem única, as duas faces juntas).
  final int index;

  /// A entrada tipada.
  final PlaylistEntry entry;

  /// Chave estável por ocorrência — ver [entryKeyFor].
  final String key;

  String get id => entry.id;

  MaterialKind get kind => entry.kind;

  bool get isAudio => entry.isAudio;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveEntry &&
          other.index == index &&
          other.entry == entry &&
          other.key == key;

  @override
  int get hashCode => Object.hash(index, entry, key);

  @override
  String toString() => 'ActiveEntry($index, $key, ${entry.kind.name})';
}

/// Chave estável por ocorrência: `id` na primeira, `'$id#$n'` na n-ésima.
///
/// [occurrence] é 0-based. A primeira ocorrência mantém o id puro para que as
/// chaves persistidas antes da repetição (a pref `carousel_focused_pdf_id`,
/// que guardava um `pdfId`) continuem válidas.
String entryKeyFor(String id, int occurrence) =>
    occurrence <= 0 ? id : '$id#$occurrence';

/// Numera as ocorrências de [entries] e devolve as entradas com chave.
List<ActiveEntry> activeEntriesOf(List<PlaylistEntry> entries) {
  final seen = <String, int>{};
  return <ActiveEntry>[
    for (var i = 0; i < entries.length; i++)
      ActiveEntry(
        index: i,
        entry: entries[i],
        key: entryKeyFor(
          entries[i].id,
          seen[entries[i].id] = (seen[entries[i].id] ?? -1) + 1,
        ),
      ),
  ];
}
