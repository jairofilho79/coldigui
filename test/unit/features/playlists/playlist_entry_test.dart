// test/unit/features/playlists/playlist_entry_test.dart
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:flutter_test/flutter_test.dart';

final pdfA = encodePdfId('ColAdultos/001.pdf');
final chordA = encodePdfId('ColAdultos/001.chord');
final gestureA = encodePdfId('ColAdultos/001.gest');
final audioA = encodePdfId('assets/praises/a/001.mp3');

/// Áudio real do Worker com container fora de `kAudioMaterialExtensions`:
/// `materialIdKindOf` devolve `unknown`.
final audioMisfiled = encodePdfId('assets/praises/a/001.mid');

void main() {
  group('PlaylistEntry.classified', () {
    test('classifica pela extensão do id', () {
      expect(PlaylistEntry.classified(pdfA).kind, MaterialKind.pdf);
      expect(PlaylistEntry.classified(chordA).kind, MaterialKind.chord);
      expect(PlaylistEntry.classified(gestureA).kind, MaterialKind.gesture);
      expect(PlaylistEntry.classified(audioA).kind, MaterialKind.audio);
    });

    test('id legado indecifrável vira unknown, nunca audio', () {
      final entry = PlaylistEntry.classified('legado-sem-base64!!!');

      expect(entry.kind, MaterialKind.unknown);
      expect(entry.isAudio, isFalse);
    });

    test('id de pdfIds legado com container estranho não vira audio', () {
      expect(
        PlaylistEntry.classified(audioMisfiled).kind,
        MaterialKind.unknown,
      );
      expect(PlaylistEntry.classified(audioMisfiled).isAudio, isFalse);
    });
  });

  group('PlaylistEntry.audio', () {
    test('declara audio mesmo com extensão não reconhecida', () {
      final entry = PlaylistEntry.audio(audioMisfiled);

      expect(entry.kind, MaterialKind.audio);
      expect(entry.isAudio, isTrue);
    });
  });

  group('PlaylistEntry.fromJson', () {
    test('objeto {id, kind} com kind audio', () {
      final entry = PlaylistEntry.fromJson({'id': audioA, 'kind': 'audio'});

      expect(entry.id, audioA);
      expect(entry.kind, MaterialKind.audio);
    });

    test('String solta (rascunho v2 da fatia 1) classifica por extensão', () {
      final entry = PlaylistEntry.fromJson(pdfA);

      expect(entry.id, pdfA);
      expect(entry.kind, MaterialKind.pdf);
    });

    test('String em declaredAudio vira audio', () {
      final entry = PlaylistEntry.fromJson(
        audioMisfiled,
        declaredAudio: {audioMisfiled},
      );

      expect(entry.kind, MaterialKind.audio);
    });

    test('kind pdf do wire com id .chord é normalizado para chord', () {
      final entry = PlaylistEntry.fromJson({'id': chordA, 'kind': 'pdf'});

      expect(
        entry.kind,
        MaterialKind.chord,
        reason: 'a extensão é mais específica que o pdf genérico do wire',
      );
    });

    test('kind unknown do wire com id .gest vira gesture', () {
      final entry = PlaylistEntry.fromJson({'id': gestureA, 'kind': 'unknown'});

      expect(entry.kind, MaterialKind.gesture);
    });

    test('kind audio do wire vence a extensão', () {
      final entry = PlaylistEntry.fromJson({
        'id': audioMisfiled,
        'kind': 'audio',
      });

      expect(entry.kind, MaterialKind.audio);
    });

    test('kind desconhecido vira unknown', () {
      final entry = PlaylistEntry.fromJson({
        'id': audioMisfiled,
        'kind': 'video',
      });

      expect(entry.kind, MaterialKind.unknown);
    });

    test('objeto sem kind cai na classificação por extensão', () {
      final entry = PlaylistEntry.fromJson({'id': chordA});

      expect(entry.kind, MaterialKind.chord);
    });

    test('id ausente ou vazio é FormatException', () {
      expect(
        () => PlaylistEntry.fromJson(<String, Object?>{'kind': 'pdf'}),
        throwsFormatException,
      );
      expect(
        () => PlaylistEntry.fromJson({'id': '', 'kind': 'pdf'}),
        throwsFormatException,
      );
      expect(() => PlaylistEntry.fromJson(42), throwsFormatException);
    });
  });

  group('PlaylistEntry.toJson', () {
    test('emite id e nome do kind', () {
      expect(PlaylistEntry.audio(audioMisfiled).toJson(), {
        'id': audioMisfiled,
        'kind': 'audio',
      });
      expect(PlaylistEntry.classified(chordA).toJson(), {
        'id': chordA,
        'kind': 'chord',
      });
    });

    test('round-trip preserva o kind declarado', () {
      final original = PlaylistEntry.audio(audioMisfiled);

      expect(PlaylistEntry.fromJson(original.toJson()), original);
    });
  });

  group('PlaylistEntry — igualdade', () {
    test('mesmo id e kind são iguais e têm o mesmo hashCode', () {
      const a = PlaylistEntry(id: 'x', kind: MaterialKind.pdf);
      const b = PlaylistEntry(id: 'x', kind: MaterialKind.pdf);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('kind diferente não é igual', () {
      const a = PlaylistEntry(id: 'x', kind: MaterialKind.pdf);
      const b = PlaylistEntry(id: 'x', kind: MaterialKind.audio);

      expect(a, isNot(b));
    });

    test('toString mostra id e kind', () {
      expect(
        const PlaylistEntry(id: 'x', kind: MaterialKind.chord).toString(),
        'PlaylistEntry(x, chord)',
      );
    });
  });

  group('resolveWireKind', () {
    test('audio permanece audio', () {
      expect(
        resolveWireKind(MaterialKind.audio, pdfA),
        MaterialKind.audio,
        reason: 'o veredito de áudio do Worker não pode ser desfeito (A8)',
      );
    });

    test('pdf/unknown viram chord ou gesture quando a extensão diz', () {
      expect(resolveWireKind(MaterialKind.pdf, chordA), MaterialKind.chord);
      expect(
        resolveWireKind(MaterialKind.unknown, gestureA),
        MaterialKind.gesture,
      );
    });

    test('pdf permanece pdf quando a extensão concorda ou não ajuda', () {
      expect(resolveWireKind(MaterialKind.pdf, pdfA), MaterialKind.pdf);
      expect(
        resolveWireKind(MaterialKind.pdf, audioMisfiled),
        MaterialKind.pdf,
        reason: 'a extensão só refina para chord/gesture',
      );
    });

    test('youtube não é reinterpretado', () {
      expect(
        resolveWireKind(MaterialKind.youtube, chordA),
        MaterialKind.youtube,
      );
    });
  });

  group('materialKindFromName', () {
    test('nome válido devolve o kind', () {
      expect(materialKindFromName('chord'), MaterialKind.chord);
      expect(materialKindFromName('audio'), MaterialKind.audio);
    });

    test('nome desconhecido ou nulo devolve unknown', () {
      expect(materialKindFromName('video'), MaterialKind.unknown);
      expect(materialKindFromName(null), MaterialKind.unknown);
    });
  });
}
