// test/unit/features/playlists/remote_playlist_schema_test.dart
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/playlists/domain/entities/remote_playlist.dart';
import 'package:flutter_test/flutter_test.dart';

final pdfA = encodePdfId('ColAdultos/001.pdf');
final pdfB = encodePdfId('ColAdultos/002.pdf');
final chordA = encodePdfId('ColAdultos/001.chord');
final audioA = encodePdfId('assets/praises/a/001.mp3');
final audioB = encodePdfId('assets/praises/b/002.mp3');

/// Áudio do Worker com container fora de `kAudioMaterialExtensions`.
final audioMisfiled = encodePdfId('assets/praises/a/001.mid');

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

  group('RemotePlaylist.toJson', () {
    test('envia schemaVersion 2, items e as duas listas derivadas', () {
      final remote = RemotePlaylist(
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
      expect(json['items'], [pdfA, audioA, pdfB]);
      expect(json['pdfIds'], [pdfA, pdfB]);
      expect(json['audioIds'], [audioA]);
    });

    test('payload montado com as listas antigas continua v2 no wire', () {
      final remote = RemotePlaylist(
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
      expect(json['items'], [pdfA, pdfB, audioA]);
    });

    test('round-trip v2 preserva a ordem única', () {
      final original = RemotePlaylist(
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
}
