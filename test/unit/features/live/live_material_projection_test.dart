import 'package:coldigui/features/live/domain/live_material_projection.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const a = PlaylistEntry(id: 'a', kind: MaterialKind.pdf);
  const b = PlaylistEntry(id: 'b', kind: MaterialKind.pdf);
  const mine = PlaylistEntry(id: 'a-trompete', kind: MaterialKind.pdf);
  const fav = PlaylistEntry(id: 'b-contralto', kind: MaterialKind.pdf);

  test('sem escolhas, é a lista do gestor com as chaves dele', () {
    final entries = projectLiveEntries(const [a, b, a]);
    expect(entries.map((e) => e.key), ['a', 'b', 'a#1']);
    expect(entries.map((e) => e.entry), [a, b, a]);
    expect(entries.map((e) => e.index), [0, 1, 2]);
  });

  test('manual > auto > gestor, sem mexer nas chaves', () {
    final entries = projectLiveEntries(
      const [a, b, a],
      manual: const {'a': mine},
      auto: (leader) => leader == b ? fav : null,
    );
    expect(entries.map((e) => e.key), ['a', 'b', 'a#1']);
    expect(entries.map((e) => e.entry), [mine, fav, a]);
  });

  test('escolha manual para chave que não existe mais é ignorada', () {
    final entries = projectLiveEntries(const [a], manual: const {'b': fav});
    expect(entries.single.entry, a);
  });
}
