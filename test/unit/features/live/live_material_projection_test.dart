import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/live/domain/live_material_projection.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const a = PlaylistEntry(id: 'a', kind: MaterialKind.pdf);
  const b = PlaylistEntry(id: 'b', kind: MaterialKind.pdf);
  const mine = PlaylistEntry(id: 'a-trompete', kind: MaterialKind.pdf);
  const fav = PlaylistEntry(id: 'b-contralto', kind: MaterialKind.pdf);

  // Ids Coldigom de verdade: dois materiais do louvor p1 e um do p2.
  final p1Pdf = PlaylistEntry(
    id: encodePdfId('assets/praises/p1/coro.pdf'),
    kind: MaterialKind.pdf,
  );
  final p1Chord = PlaylistEntry(
    id: encodePdfId('assets/praises/p1/cifra.chord'),
    kind: MaterialKind.chord,
  );
  final p2Pdf = PlaylistEntry(
    id: encodePdfId('assets/praises/p2/coro.pdf'),
    kind: MaterialKind.pdf,
  );

  group('ids fora do Coldigom (fallback: chave de material)', () {
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
  });

  group('ids Coldigom: a chave é o louvor, não o material', () {
    test('a chave sobrevive à troca de material do gestor', () {
      final before = projectLiveEntries([p1Pdf, p2Pdf]);
      final after = projectLiveEntries([p1Chord, p2Pdf]);
      expect(before.map((e) => e.key), ['praise:p1', 'praise:p2']);
      expect(after.map((e) => e.key), before.map((e) => e.key));
      expect(after.first.entry, p1Chord);
    });

    test('o mesmo louvor repetido numera por ocorrência do louvor', () {
      final entries = projectLiveEntries([p1Pdf, p2Pdf, p1Chord]);
      expect(entries.map((e) => e.key), [
        'praise:p1',
        'praise:p2',
        'praise:p1#1',
      ]);
    });

    test('a escolha do consumidor fica presa ao louvor', () {
      final chosen = projectLiveEntries(
        [p1Pdf],
        manual: {'praise:p1': p1Chord},
      );
      expect(chosen.single.entry, p1Chord);
      // O gestor trocou o material dele: a chave não mudou, a escolha fica.
      final afterSwap = projectLiveEntries(
        [
          PlaylistEntry(
            id: encodePdfId('assets/praises/p1/outro.pdf'),
            kind: MaterialKind.pdf,
          ),
        ],
        manual: {'praise:p1': p1Chord},
      );
      expect(afterSwap.single.key, 'praise:p1');
      expect(afterSwap.single.entry, p1Chord);
    });

    test('mistura: Coldigom por louvor, o resto por material', () {
      final entries = projectLiveEntries([p1Pdf, a, a]);
      expect(entries.map((e) => e.key), ['praise:p1', 'a', 'a#1']);
    });
  });

  group('liveConsumerKeyForLeaderKey', () {
    test('traduz a chave de foco do gestor (material) para a da projeção', () {
      final leader = [p1Pdf, p2Pdf, p1Pdf];
      expect(liveConsumerKeyForLeaderKey(leader, p1Pdf.id), 'praise:p1');
      expect(liveConsumerKeyForLeaderKey(leader, p2Pdf.id), 'praise:p2');
      expect(
        liveConsumerKeyForLeaderKey(leader, '${p1Pdf.id}#1'),
        'praise:p1#1',
      );
    });

    test('chave que não está na lista do gestor → null', () {
      expect(liveConsumerKeyForLeaderKey([p1Pdf], 'zzz'), isNull);
    });

    test('fora do Coldigom a chave é a mesma', () {
      expect(liveConsumerKeyForLeaderKey(const [a, b, a], 'a#1'), 'a#1');
    });
  });
}
