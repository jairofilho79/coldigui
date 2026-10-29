import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/domain/utils/content_fingerprint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('junta kind:id por entrada, na ordem, separado por vírgula', () {
    const entries = [
      PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
      PlaylistEntry(id: 'b', kind: MaterialKind.audio),
    ];

    expect(contentFingerprint(entries), 'pdf:a,audio:b');
  });

  test('lista vazia gera string vazia', () {
    expect(contentFingerprint(const []), '');
  });

  test('a ordem importa — mesmas entradas em ordem diferente divergem', () {
    const a = [
      PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
      PlaylistEntry(id: 'b', kind: MaterialKind.audio),
    ];
    const b = [
      PlaylistEntry(id: 'b', kind: MaterialKind.audio),
      PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
    ];

    expect(contentFingerprint(a), isNot(contentFingerprint(b)));
  });

  test('o kind importa — mesmo id com kind diferente diverge', () {
    const a = [PlaylistEntry(id: 'a', kind: MaterialKind.pdf)];
    const b = [PlaylistEntry(id: 'a', kind: MaterialKind.chord)];

    expect(contentFingerprint(a), isNot(contentFingerprint(b)));
  });

  test('duas listas com as mesmas entradas na mesma ordem batem', () {
    const a = [
      PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
      PlaylistEntry(id: 'b', kind: MaterialKind.audio),
    ];
    const b = [
      PlaylistEntry(id: 'a', kind: MaterialKind.pdf),
      PlaylistEntry(id: 'b', kind: MaterialKind.audio),
    ];

    expect(contentFingerprint(a), contentFingerprint(b));
  });
}
