import 'package:coldigui/features/playlists/domain/entities/active_entry.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'activeEntriesOf dá chave id na primeira ocorrência e id#1 na segunda',
    () {
      final entries = [
        PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
        PlaylistEntry(id: 'b', kind: MaterialKind.audio),
        PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
        PlaylistEntry(id: 'a', kind: MaterialKind.chord),
      ];

      final actives = activeEntriesOf(entries);

      expect(actives.map((e) => e.key), ['a', 'b', 'a#1', 'a#2']);
      expect(actives.map((e) => e.index), [0, 1, 2, 3]);
      expect(actives[1].isAudio, isTrue);
      expect(actives[3].kind, MaterialKind.chord);
      expect(actives[3].id, 'a');
    },
  );

  test('entryKeyFor devolve o id puro na ocorrência 0', () {
    expect(entryKeyFor('x', 0), 'x');
    expect(entryKeyFor('x', 1), 'x#1');
    expect(entryKeyFor('x', 7), 'x#7');
  });

  test('activeEntriesOf de lista vazia é vazia', () {
    expect(activeEntriesOf(const []), isEmpty);
  });
}
