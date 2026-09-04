// test/unit/features/playlists/saved_playlist_entries_test.dart
//
// Porta para `entries` os casos de projeção/ordem que a fatia 1 fixou em
// `playlist_material_order_test.dart` (grupos de entidade). Os grupos de Isar e
// de repositório continuam lá.
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:flutter_test/flutter_test.dart';

final pdfA = encodePdfId('ColAdultos/001.pdf');
final pdfB = encodePdfId('ColAdultos/002.pdf');
final pdfC = encodePdfId('ColAdultos/003.pdf');
final chordA = encodePdfId('ColAdultos/001.chord');
final gestureA = encodePdfId('ColAdultos/001.gest');
final audioA = encodePdfId('assets/praises/a/001.mp3');
final audioB = encodePdfId('assets/praises/b/002.mp3');

/// Áudio real do Worker com container fora de [kAudioMaterialExtensions].
final audioMisfiled = encodePdfId('assets/praises/a/001.mid');

/// Áudio `.aac` — extensão reconhecida, mas não `.mp3`.
final audioAac = encodePdfId('assets/praises/c/003.aac');

SavedPlaylist _legacy({
  List<String>? items,
  List<String> pdfIds = const [],
  List<String> audioIds = const [],
}) => SavedPlaylist.fromLegacyLists(
  playlistId: 'p1',
  nome: 'Lista',
  items: items,
  pdfIds: pdfIds,
  audioIds: audioIds,
  createdAt: DateTime.utc(2026, 9, 1),
);

List<MaterialKind> _kinds(SavedPlaylist p) =>
    p.entries.map((e) => e.kind).toList();

void main() {
  group('SavedPlaylist.fromLegacyLists', () {
    test('pdfIds classificam por extensão e audioIds viram audio', () {
      final playlist = _legacy(pdfIds: [pdfA, chordA], audioIds: [audioA]);

      expect(_kinds(playlist), [
        MaterialKind.pdf,
        MaterialKind.chord,
        MaterialKind.audio,
      ]);
      expect(playlist.items, [pdfA, chordA, audioA]);
      expect(playlist.pdfIds, [pdfA, chordA]);
      expect(playlist.audioIds, [audioA]);
    });

    test('id .aac declarado em audioIds nunca cai na face de partituras', () {
      final playlist = _legacy(pdfIds: [pdfA], audioIds: [audioAac]);

      expect(materialIdKindOf(audioAac), MaterialKind.audio);
      expect(playlist.audioIds, [audioAac]);
      expect(playlist.pdfIds, [pdfA]);
    });

    test('audioIds com container estranho ainda é audio (A8)', () {
      final playlist = _legacy(
        items: [pdfA, audioMisfiled, audioA],
        audioIds: [audioMisfiled, audioA],
      );

      expect(
        playlist.audioIds,
        [audioMisfiled, audioA],
        reason: 'quem gravou a lista já decidiu que este id é áudio',
      );
      expect(playlist.pdfIds, [pdfA]);
    });

    test('items tem precedência sobre pdfIds/audioIds', () {
      final playlist = _legacy(
        items: [audioA, pdfA],
        pdfIds: [pdfB],
        audioIds: [audioB],
      );

      expect(playlist.items, [audioA, pdfA]);
      expect(_kinds(playlist), [MaterialKind.audio, MaterialKind.pdf]);
    });
  });

  group('SavedPlaylist — projeções derivadas de entries', () {
    test('pdfIds e audioIds derivam de entries pela ordem única', () {
      final playlist = _legacy(items: [pdfA, audioA, chordA, pdfB, audioB]);

      expect(playlist.pdfIds, [pdfA, chordA, pdfB]);
      expect(playlist.audioIds, [audioA, audioB]);
      expect(playlist.items, [pdfA, audioA, chordA, pdfB, audioB]);
    });

    test('cifra entra em pdfIds e não em audioIds', () {
      final playlist = _legacy(items: [chordA]);

      expect(playlist.pdfIds, [chordA]);
      expect(playlist.audioIds, isEmpty);
    });

    test('gesto entra em pdfIds e não some das duas faces (A7)', () {
      final playlist = _legacy(items: [pdfA, gestureA, audioA]);

      expect(
        playlist.pdfIds,
        [pdfA, gestureA],
        reason: 'gesto é material de leitura — abre no leitor como PDF/cifra',
      );
      expect(playlist.audioIds, [audioA]);
    });

    test('id legado indecifrável fica com os PDFs', () {
      final playlist = _legacy(items: ['legado-sem-base64!!!', audioA]);

      expect(playlist.pdfIds, ['legado-sem-base64!!!']);
      expect(playlist.audioIds, [audioA]);
    });

    test('round-trip: fromLegacyLists devolve as mesmas listas', () {
      final playlist = _legacy(
        pdfIds: [pdfA, chordA, pdfB],
        audioIds: [audioA, audioB],
      );

      expect(playlist.items, [pdfA, chordA, pdfB, audioA, audioB]);
      expect(playlist.pdfIds, [pdfA, chordA, pdfB]);
      expect(playlist.audioIds, [audioA, audioB]);
    });
  });

  group('SavedPlaylist.copyWith — substituição parcial de face', () {
    test('reorder de pdfIds preserva a posição dos áudios', () {
      final before = _legacy(items: [pdfA, audioA, pdfB, audioB, pdfC]);

      final after = before.copyWith(pdfIds: [pdfC, pdfB, pdfA]);

      expect(after.items, [pdfC, audioA, pdfB, audioB, pdfA]);
      expect(after.audioIds, [audioA, audioB]);
    });

    test('remoção de PDF apaga o slot e não move os áudios', () {
      final before = _legacy(items: [pdfA, audioA, pdfB, audioB]);

      final after = before.copyWith(pdfIds: [pdfB]);

      expect(after.items, [pdfB, audioA, audioB]);
    });

    test('PDF novo entra logo depois do último slot PDF', () {
      final before = _legacy(items: [pdfA, audioA, pdfB, audioB]);

      final after = before.copyWith(pdfIds: [pdfA, pdfB, pdfC]);

      expect(after.items, [pdfA, audioA, pdfB, pdfC, audioB]);
    });

    test('sem slot PDF anterior, os novos PDFs vão para o fim', () {
      final before = _legacy(items: [audioA, audioB]);

      final after = before.copyWith(pdfIds: [pdfA]);

      expect(after.items, [audioA, audioB, pdfA]);
      expect(after.audioIds, [audioA, audioB]);
    });

    test('áudio novo entra depois do último slot de áudio', () {
      final before = _legacy(items: [pdfA, audioA, pdfB]);

      final after = before.copyWith(audioIds: [audioA, audioB]);

      expect(after.items, [pdfA, audioA, audioB, pdfB]);
      expect(after.pdfIds, [pdfA, pdfB]);
    });

    test('remoção de áudio não move os PDFs', () {
      final before = _legacy(items: [pdfA, audioA, pdfB, audioB]);

      final after = before.copyWith(audioIds: [audioB]);

      expect(after.items, [pdfA, audioB, pdfB]);
    });

    test('entries explícito substitui tudo e ignora as duas projeções', () {
      final before = _legacy(items: [pdfA, audioA]);

      final after = before.copyWith(
        entries: [PlaylistEntry.audio(audioA), PlaylistEntry.classified(pdfA)],
        pdfIds: [pdfB],
      );

      expect(after.items, [audioA, pdfA]);
      expect(_kinds(after), [MaterialKind.audio, MaterialKind.pdf]);
    });

    test('copyWith sem listas mantém a ordem única', () {
      final before = _legacy(items: [pdfA, audioA, pdfB]);

      expect(before.copyWith(nome: 'Outro').items, [pdfA, audioA, pdfB]);
    });

    test('áudio com container não reconhecido fica na face de áudio', () {
      // `type: mp3` no worker, extensão fora de kAudioMaterialExtensions: o id
      // não classifica como áudio, mas o chamador o declarou em `audioIds:`.
      expect(materialIdKindOf(audioMisfiled), isNot(MaterialKind.audio));

      final before = _legacy(items: [pdfA, audioA]);
      final after = before.copyWith(audioIds: [audioA, audioMisfiled]);

      expect(after.items, [pdfA, audioA, audioMisfiled]);
      expect(after.audioIds, [audioA, audioMisfiled]);
      expect(after.pdfIds, [pdfA]);
    });

    test('reordenar a face de áudio com id estranho é estável', () {
      // O id entrou como `unknown` (face de partituras); ao ser passado em
      // `audioIds:` ele **migra** de face, sem duplicar na ordem única.
      final before = _legacy(items: [pdfA, audioA, audioMisfiled]);

      final after = before.copyWith(audioIds: [audioA, audioMisfiled]);

      expect(after.items, [pdfA, audioA, audioMisfiled]);
      expect(after.audioIds, [audioA, audioMisfiled]);
      expect(after.pdfIds, [pdfA]);
    });

    test('sync do carousel na face PDF não engole o áudio declarado (A8)', () {
      final before = _legacy(
        items: [pdfA, audioA, audioMisfiled],
        audioIds: [audioA, audioMisfiled],
      );

      // O carousel reescreve só a face de partituras.
      final after = before.copyWith(pdfIds: [pdfA, pdfB]);

      expect(after.items, [pdfA, pdfB, audioA, audioMisfiled]);
      expect(after.audioIds, [audioA, audioMisfiled]);
      expect(after.pdfIds, [pdfA, pdfB]);
    });

    test('id de áudio repassado em pdfIds não duplica na ordem única', () {
      // O carousel devolve a lista inteira que ele conhece; se um id de áudio
      // escapar para dentro dela, o slot de áudio não pode virar dois.
      final before = _legacy(items: [pdfA, audioA, pdfB]);

      final after = before.copyWith(pdfIds: [pdfA, audioA, pdfB]);

      expect(after.items, [pdfA, audioA, pdfB]);
      expect(after.audioIds, [audioA]);
      expect(after.pdfIds, [pdfA, pdfB]);
    });

    test('áudio declarado repassado em pdfIds não muda de face (A8)', () {
      final before = _legacy(
        items: [pdfA, audioMisfiled],
        audioIds: [audioMisfiled],
      );

      final after = before.copyWith(pdfIds: [pdfA, audioMisfiled]);

      expect(after.items, [pdfA, audioMisfiled]);
      expect(after.audioIds, [
        audioMisfiled,
      ], reason: 'pdfIds: nunca rebaixa uma entrada que já é áudio');
      expect(after.pdfIds, [pdfA]);
    });

    test('kind declarado no wire sobrevive ao sync da face de partituras', () {
      // `youtube` não decodifica como path: reclassificar pela extensão o
      // rebaixaria para `unknown` a cada sync do carousel.
      final youtubeId = 'yt:dQw4w9WgXcQ';
      final before = SavedPlaylist(
        playlistId: 'p1',
        nome: 'Lista',
        entries: [
          PlaylistEntry.classified(pdfA),
          const PlaylistEntry(id: 'yt:dQw4w9WgXcQ', kind: MaterialKind.youtube),
        ],
        createdAt: DateTime.utc(2026, 9, 1),
      );

      final after = before.copyWith(pdfIds: [pdfA, youtubeId]);

      expect(after.items, [pdfA, youtubeId]);
      expect(_kinds(after), [MaterialKind.pdf, MaterialKind.youtube]);
    });

    test('cifra existente não é reclassificada por pdfIds', () {
      final before = _legacy(items: [chordA, pdfA]);

      final after = before.copyWith(pdfIds: [pdfA, chordA]);

      expect(after.items, [pdfA, chordA]);
      expect(_kinds(after), [MaterialKind.pdf, MaterialKind.chord]);
    });

    test('id novo em pdfIds é classificado pela extensão', () {
      final before = _legacy(items: [pdfA]);

      final after = before.copyWith(pdfIds: [pdfA, chordA, gestureA]);

      expect(_kinds(after), [
        MaterialKind.pdf,
        MaterialKind.chord,
        MaterialKind.gesture,
      ]);
    });

    test('id .aac reordenado na face de áudio não migra para partituras', () {
      final before = _legacy(
        items: [pdfA, audioAac, audioA],
        audioIds: [audioAac, audioA],
      );

      final after = before.copyWith(audioIds: [audioA, audioAac]);

      expect(after.items, [pdfA, audioA, audioAac]);
      expect(after.audioIds, [audioA, audioAac]);
      expect(after.pdfIds, [pdfA]);
    });
  });

  group('SavedPlaylist.replaceSubset', () {
    test('preserva a posição relativa do subconjunto intocado', () {
      final current = [
        PlaylistEntry.classified(pdfA),
        PlaylistEntry.audio(audioA),
        PlaylistEntry.classified(pdfB),
      ];

      final next = SavedPlaylist.replaceSubset(current, [
        PlaylistEntry.classified(pdfB),
        PlaylistEntry.classified(pdfA),
      ], (e) => !e.isAudio);

      expect(next.map((e) => e.id), [pdfB, audioA, pdfA]);
    });

    test('aceita next fora da face sem assert (kind manda)', () {
      final current = [PlaylistEntry.classified(pdfA)];

      final next = SavedPlaylist.replaceSubset(current, [
        PlaylistEntry.audio(audioA),
      ], (e) => !e.isAudio);

      expect(next.map((e) => e.id), [audioA]);
    });
  });
}
