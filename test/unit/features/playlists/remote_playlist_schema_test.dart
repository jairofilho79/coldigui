// test/unit/features/playlists/remote_playlist_schema_test.dart
import 'dart:convert';

import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/domain/entities/remote_playlist.dart';
import 'package:flutter_test/flutter_test.dart';

final pdfA = encodePdfId('ColAdultos/001.pdf');
final pdfB = encodePdfId('ColAdultos/002.pdf');
final chordA = encodePdfId('ColAdultos/001.chord');
final gestureA = encodePdfId('ColAdultos/001.gest');
final audioA = encodePdfId('assets/praises/a/001.mp3');
final audioB = encodePdfId('assets/praises/b/002.mp3');

/// Áudio do Worker com container fora de `kAudioMaterialExtensions`.
final audioMisfiled = encodePdfId('assets/praises/a/001.mid');

/// Id que não é caminho de arquivo — a extensão não classifica nada.
const youtubeA = 'yt:dQw4w9WgXcQ';

Map<String, dynamic> _baseJson() => {
  'id': 'p1',
  'nome': 'Ensaio',
  'salva': true,
  'favorita': false,
  'createdAt': '2026-09-01T10:00:00.000Z',
  'updatedAt': '2026-09-02T10:00:00.000Z',
  'version': 3,
};

void main() {
  group('RemotePlaylist.fromJson — v1', () {
    test('sem schemaVersion nem items, items = pdfIds + audioIds', () {
      final remote = RemotePlaylist.fromJson({
        ..._baseJson(),
        'pdfIds': [pdfA, pdfB],
        'audioIds': [audioA],
      });

      expect(remote.schemaVersion, 1);
      expect(remote.items, [pdfA, pdfB, audioA]);
      expect(remote.pdfIds, [pdfA, pdfB]);
      expect(remote.audioIds, [audioA]);
    });

    test('payload v1 sem listas nenhuma vira items vazio', () {
      final remote = RemotePlaylist.fromJson(_baseJson());

      expect(remote.schemaVersion, 1);
      expect(remote.items, isEmpty);
      expect(remote.pdfIds, isEmpty);
      expect(remote.audioIds, isEmpty);
    });
  });

  group('RemotePlaylist.fromJson — v2', () {
    test('items manda e preserva o intercalado', () {
      final remote = RemotePlaylist.fromJson({
        ..._baseJson(),
        'schemaVersion': 2,
        'items': [pdfA, audioA, chordA, audioB, pdfB],
        // O Worker devolve as derivadas; elas não podem sobrescrever a ordem.
        'pdfIds': [pdfA, chordA, pdfB],
        'audioIds': [audioA, audioB],
      });

      expect(remote.schemaVersion, 2);
      expect(remote.items, [pdfA, audioA, chordA, audioB, pdfB]);
      expect(remote.pdfIds, [pdfA, chordA, pdfB]);
      expect(remote.audioIds, [audioA, audioB]);
    });

    test('items presente sem schemaVersion ainda é lido como v2', () {
      final remote = RemotePlaylist.fromJson({
        ..._baseJson(),
        'items': [audioA, pdfA],
      });

      expect(remote.schemaVersion, 2);
      expect(remote.items, [audioA, pdfA]);
    });
  });

  group('RemotePlaylist.fromJson — v2 com items de objetos', () {
    test('kind do wire tipa cada entrada, sem consultar as listas', () {
      final remote = RemotePlaylist.fromJson({
        ..._baseJson(),
        'schemaVersion': 2,
        'items': [
          {'id': pdfA, 'kind': 'pdf'},
          {'id': audioA, 'kind': 'audio'},
          {'id': youtubeA, 'kind': 'youtube'},
        ],
        // Listas derivadas do Worker: não podem mudar nem a ordem nem o tipo.
        'pdfIds': [pdfA, youtubeA],
        'audioIds': [audioA],
      });

      expect(remote.entries.map((e) => e.kind), [
        MaterialKind.pdf,
        MaterialKind.audio,
        MaterialKind.youtube,
      ]);
      expect(remote.items, [pdfA, audioA, youtubeA]);
      expect(remote.pdfIds, [pdfA, youtubeA]);
      expect(remote.audioIds, [audioA]);
    });

    test('kind pdf num id .chord é refinado por resolveWireKind', () {
      // O Worker que derivar `items` das listas v1 marca toda cifra como `pdf`;
      // a extensão (mais específica) recupera `chord` na leitura (A.3).
      final remote = RemotePlaylist.fromJson({
        ..._baseJson(),
        'schemaVersion': 2,
        'items': [
          {'id': chordA, 'kind': 'pdf'},
          {'id': gestureA, 'kind': 'pdf'},
        ],
      });

      expect(remote.entries.map((e) => e.kind), [
        MaterialKind.chord,
        MaterialKind.gesture,
      ]);
    });

    test('kind fora do enum vira unknown, sem derrubar a leitura', () {
      final remote = RemotePlaylist.fromJson({
        ..._baseJson(),
        'schemaVersion': 2,
        'items': [
          {'id': pdfA, 'kind': 'video'},
        ],
      });

      expect(remote.entries.single.kind, MaterialKind.unknown);
      // `unknown` não é áudio: continua na face de partituras (A7).
      expect(remote.pdfIds, [pdfA]);
    });

    test('kind audio vence a extensão do id (A8)', () {
      final remote = RemotePlaylist.fromJson({
        ..._baseJson(),
        'schemaVersion': 2,
        'items': [
          {'id': audioMisfiled, 'kind': 'audio'},
        ],
        // As listas derivadas discordam de propósito: `items` manda.
        'pdfIds': [audioMisfiled],
        'audioIds': <String>[],
      });

      expect(remote.audioIds, [audioMisfiled]);
      expect(remote.pdfIds, isEmpty);
    });

    test('objeto sem kind cai na classificação por extensão + audioIds', () {
      final remote = RemotePlaylist.fromJson({
        ..._baseJson(),
        'schemaVersion': 2,
        'items': [
          {'id': chordA},
          {'id': audioMisfiled},
        ],
        'audioIds': [audioMisfiled],
      });

      expect(remote.entries.map((e) => e.kind), [
        MaterialKind.chord,
        MaterialKind.audio,
      ]);
    });

    test('items de objetos e de strings misturados são aceitos', () {
      final remote = RemotePlaylist.fromJson({
        ..._baseJson(),
        'schemaVersion': 2,
        'items': [
          {'id': pdfA, 'kind': 'pdf'},
          audioMisfiled,
        ],
        'audioIds': [audioMisfiled],
      });

      expect(remote.entries.map((e) => e.kind), [
        MaterialKind.pdf,
        MaterialKind.audio,
      ]);
    });
  });

  group('RemotePlaylist.fromJson — FormatException nomeando o campo', () {
    test('id ausente', () {
      expect(
        () => RemotePlaylist.fromJson({..._baseJson()}..remove('id')),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('id'),
          ),
        ),
      );
    });

    test('nome ausente', () {
      expect(
        () => RemotePlaylist.fromJson({..._baseJson()}..remove('nome')),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('nome'),
          ),
        ),
      );
    });

    test('createdAt ausente', () {
      expect(
        () => RemotePlaylist.fromJson({..._baseJson()}..remove('createdAt')),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('createdAt'),
          ),
        ),
      );
    });

    test('updatedAt inválido', () {
      expect(
        () => RemotePlaylist.fromJson({..._baseJson(), 'updatedAt': 'ontem'}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('updatedAt'),
          ),
        ),
      );
    });

    test('items que não é lista', () {
      expect(
        () => RemotePlaylist.fromJson({..._baseJson(), 'items': 'pdfA,audioA'}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('items'),
          ),
        ),
      );
    });

    test('entrada de items sem id', () {
      expect(
        () => RemotePlaylist.fromJson({
          ..._baseJson(),
          'items': [
            {'kind': 'pdf'},
          ],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('pdfIds que não é lista de strings', () {
      expect(
        () => RemotePlaylist.fromJson({
          ..._baseJson(),
          'pdfIds': [1, 2],
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('pdfIds'),
          ),
        ),
      );
    });
  });

  group('RemotePlaylist.toJson', () {
    test('envia schemaVersion 2, items e as duas listas derivadas', () {
      final remote = RemotePlaylist.fromLegacyLists(
        id: 'p1',
        nome: 'Ensaio',
        items: [pdfA, audioA, pdfB],
        salva: true,
        favorita: false,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 2),
        version: 3,
      );

      final json = remote.toJson();

      expect(json['schemaVersion'], 2);
      expect(json['items'], [
        {'id': pdfA, 'kind': 'pdf'},
        {'id': audioA, 'kind': 'audio'},
        {'id': pdfB, 'kind': 'pdf'},
      ]);
      expect(json['pdfIds'], [pdfA, pdfB]);
      expect(json['audioIds'], [audioA]);
    });

    test('items é serializável em JSON puro', () {
      final remote = RemotePlaylist(
        id: 'p1',
        nome: 'Ensaio',
        entries: [
          PlaylistEntry(id: chordA, kind: MaterialKind.chord),
          PlaylistEntry(id: youtubeA, kind: MaterialKind.youtube),
        ],
        salva: true,
        favorita: false,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 2),
        version: 1,
      );

      final decoded =
          jsonDecode(jsonEncode(remote.toJson())) as Map<String, dynamic>;

      expect(decoded['items'], [
        {'id': chordA, 'kind': 'chord'},
        {'id': youtubeA, 'kind': 'youtube'},
      ]);
    });

    test('round-trip preserva kinds que a extensão não recupera', () {
      final original = RemotePlaylist(
        id: 'p1',
        nome: 'Ensaio',
        entries: [
          PlaylistEntry(id: youtubeA, kind: MaterialKind.youtube),
          PlaylistEntry(id: audioMisfiled, kind: MaterialKind.audio),
          PlaylistEntry(id: pdfA, kind: MaterialKind.pdf),
        ],
        salva: true,
        favorita: false,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 2),
        version: 4,
      );

      final parsed = RemotePlaylist.fromJson(original.toJson());

      expect(parsed.entries, original.entries);
    });

    test('payload montado com as listas antigas continua v2 no wire', () {
      final remote = RemotePlaylist.fromLegacyLists(
        id: 'p1',
        nome: 'Ensaio',
        pdfIds: [pdfA, pdfB],
        audioIds: [audioA],
        salva: true,
        favorita: false,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 2),
        version: 1,
      );

      final json = remote.toJson();

      expect(json['schemaVersion'], 2);
      expect(json['items'], [
        {'id': pdfA, 'kind': 'pdf'},
        {'id': pdfB, 'kind': 'pdf'},
        {'id': audioA, 'kind': 'audio'},
      ]);
    });

    test('round-trip v2 preserva a ordem única', () {
      final original = RemotePlaylist.fromLegacyLists(
        id: 'p1',
        nome: 'Ensaio',
        items: [audioA, pdfA, audioB, chordA],
        salva: true,
        favorita: true,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 2),
        version: 7,
      );

      final parsed = RemotePlaylist.fromJson(original.toJson());

      expect(parsed.items, original.items);
      expect(parsed.pdfIds, original.pdfIds);
      expect(parsed.audioIds, original.audioIds);
      expect(parsed.schemaVersion, 2);
      expect(parsed.version, 7);
    });

    test('audioIds do payload vencem a extensão do id (A8)', () {
      final remote = RemotePlaylist.fromJson({
        ..._baseJson(),
        'schemaVersion': 2,
        'items': [pdfA, audioMisfiled],
        'pdfIds': [pdfA],
        'audioIds': [audioMisfiled],
      });

      expect(remote.audioIds, [audioMisfiled]);
      expect(remote.pdfIds, [pdfA]);

      // Round-trip: o veredito sobrevive ao toJson/fromJson.
      final parsed = RemotePlaylist.fromJson(remote.toJson());
      expect(parsed.audioIds, [audioMisfiled]);
      expect(parsed.pdfIds, [pdfA]);
    });
  });

  group('RemotePlaylist.fromJson — deletedAt (A.2)', () {
    test('lê o tombstone do Worker', () {
      final remote = RemotePlaylist.fromJson({
        ..._baseJson(),
        'deletedAt': '2026-09-03T10:00:00.000Z',
      });

      expect(remote.deletedAt, DateTime.utc(2026, 9, 3, 10));
    });

    test('Worker sem o campo (ou com null) vira deletedAt nulo', () {
      expect(RemotePlaylist.fromJson(_baseJson()).deletedAt, isNull);
      expect(
        RemotePlaylist.fromJson({..._baseJson(), 'deletedAt': null}).deletedAt,
        isNull,
      );
    });

    test('deletedAt ilegível lança FormatException nomeando o campo', () {
      expect(
        () => RemotePlaylist.fromJson({..._baseJson(), 'deletedAt': 'ontem'}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('deletedAt'),
          ),
        ),
      );
    });
  });
}
