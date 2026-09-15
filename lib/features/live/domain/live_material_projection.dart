import '../../playlists/domain/entities/active_entry.dart';
import '../../playlists/domain/entities/playlist_entry.dart';

/// Escolhe o material **do consumidor** para uma entrada do gestor, ou `null`
/// para ficar com a dele. Quem implementa consulta o grupo Coldigom do
/// louvor e os favoritos da conta — isso é da camada de apresentação.
typedef LiveMaterialResolver = PlaylistEntry? Function(PlaylistEntry leader);

/// A lista do gestor como o consumidor a vê: **as chaves do gestor** (é por
/// elas que o foco viaja no wire) com **o material do consumidor** em cada
/// posição.
///
/// Precedência por chave: escolha manual em [manual] (sheet de materiais) >
/// [auto] (favoritos) > a própria entrada do gestor. As chaves são as de
/// [activeEntriesOf] sobre as entradas do gestor, e não mudam quando o
/// material projetado muda — assim «seguir o foco» continua a bater chave
/// com chave, e uma troca manual não parece uma navegação do consumidor.
List<ActiveEntry> projectLiveEntries(
  List<PlaylistEntry> leaderEntries, {
  Map<String, PlaylistEntry> manual = const {},
  LiveMaterialResolver? auto,
}) => [
  for (final leader in activeEntriesOf(leaderEntries))
    ActiveEntry(
      index: leader.index,
      key: leader.key,
      entry: manual[leader.key] ?? auto?.call(leader.entry) ?? leader.entry,
    ),
];
