import '../../coldigom/domain/utils/coldigom_praise_id.dart';
import '../../playlists/domain/entities/active_entry.dart';
import '../../playlists/domain/entities/playlist_entry.dart';

/// Escolhe o material **do consumidor** para uma entrada do gestor, ou `null`
/// para ficar com a dele. Quem implementa consulta o grupo Coldigom do
/// louvor e os favoritos da conta — isso é da camada de apresentação.
typedef LiveMaterialResolver = PlaylistEntry? Function(PlaylistEntry leader);

/// Chaves da projeção do consumidor, **por louvor**: `praise:<praiseId>` na
/// primeira ocorrência do louvor e `praise:<praiseId>#n` na n-ésima. Uma
/// entrada sem louvor Coldigom (YouTube, id fora do acervo) cai na chave de
/// material de sempre ([entryKeyFor]) — a mesma que o gestor usa.
///
/// É isto que faz a lista obedecer ao **louvor** e não ao material: quando o
/// gestor troca a partitura de um louvor por cifra/gestos, o id da entrada
/// muda, mas a chave (foco do consumidor, escolha manual, favoritos) fica.
List<String> livePraiseKeysOf(List<PlaylistEntry> entries) {
  final seen = <String, int>{};
  return [
    for (final entry in entries)
      switch (coldigomPraiseIdFromPdfId(entry.id)) {
        final praiseId? => _praiseKey(
          praiseId,
          seen['p:$praiseId'] = (seen['p:$praiseId'] ?? -1) + 1,
        ),
        null => entryKeyFor(
          entry.id,
          seen['m:${entry.id}'] = (seen['m:${entry.id}'] ?? -1) + 1,
        ),
      },
  ];
}

String _praiseKey(String praiseId, int occurrence) =>
    occurrence <= 0 ? 'praise:$praiseId' : 'praise:$praiseId#$occurrence';

/// A lista do gestor como o consumidor a vê: **chaves por louvor**
/// ([livePraiseKeysOf]) com **o material do consumidor** em cada posição.
///
/// Precedência por chave: escolha manual em [manual] (sheet de materiais) >
/// [auto] (favoritos) > a própria entrada do gestor. As chaves não mudam
/// quando o material projetado muda, nem quando o gestor troca o dele —
/// assim «seguir o foco» continua a bater chave com chave, e uma troca de
/// material (de qualquer lado) não parece uma navegação.
List<ActiveEntry> projectLiveEntries(
  List<PlaylistEntry> leaderEntries, {
  Map<String, PlaylistEntry> manual = const {},
  LiveMaterialResolver? auto,
}) {
  final keys = livePraiseKeysOf(leaderEntries);
  return [
    for (var i = 0; i < leaderEntries.length; i++)
      ActiveEntry(
        index: i,
        key: keys[i],
        entry:
            manual[keys[i]] ?? auto?.call(leaderEntries[i]) ?? leaderEntries[i],
      ),
  ];
}

/// Traduz a chave de foco que o gestor manda no wire (chave de **material**,
/// [activeEntriesOf] sobre as entradas dele) para a chave da projeção
/// ([livePraiseKeysOf]) na mesma posição. `null` se a chave não está na
/// lista do gestor.
String? liveConsumerKeyForLeaderKey(
  List<PlaylistEntry> leaderEntries,
  String leaderKey,
) {
  final leader = activeEntriesOf(leaderEntries);
  final index = leader.indexWhere((e) => e.key == leaderKey);
  if (index < 0) return null;
  return livePraiseKeysOf(leaderEntries)[index];
}
