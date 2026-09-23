import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/utils/preferred_entry_for_praise.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/praise_share_fixtures.dart';

void main() {
  final pdfId = praiseMaterialId('p1', 'partitura.pdf');
  final audioId = praiseMaterialId('p1', 'audio.mp3');
  final onlyAudioId = praiseMaterialId('p2', 'audio.mp3');
  final chordId = praiseMaterialId('p3', 'cifra.chord');
  final gestureOfChordId = praiseMaterialId('p3', 'gestos.gestures');
  final gestureId = praiseMaterialId('p4', 'gestos.gestures');
  final index = praiseIndex([
    praiseGroup(
      praiseId: 'p1',
      shortId: '0a1',
      pdfs: [praisePdf(praiseId: 'p1', pdfId: pdfId, materialKindId: 'k-part')],
      audios: [
        praiseAudio(
          praiseId: 'p1',
          audioId: audioId,
          materialKindId: 'k-audio',
        ),
      ],
    ),
    praiseGroup(
      praiseId: 'p2',
      shortId: '0c3',
      audios: [praiseAudio(praiseId: 'p2', audioId: onlyAudioId)],
    ),
    praiseGroup(
      praiseId: 'p3',
      shortId: 'fff',
      chords: [praiseChord(praiseId: 'p3', chordId: chordId)],
      gestures: [praiseGesture(praiseId: 'p3', gestureId: gestureOfChordId)],
      withLyrics: true,
    ),
    praiseGroup(
      praiseId: 'p4',
      shortId: '4d4',
      gestures: [praiseGesture(praiseId: 'p4', gestureId: gestureId)],
      withLyrics: true,
    ),
    praiseGroup(praiseId: 'p5', shortId: '5e5', withLyrics: true),
  ]);

  test('sem favoritos: PDF principal', () {
    expect(
      preferredEntryForPraise(index, '0a1'),
      PlaylistEntry(id: pdfId, kind: MaterialKind.pdf),
    );
  });

  test('com favoritos: o material do favorito mais bem colocado', () {
    expect(
      preferredEntryForPraise(
        index,
        '0a1',
        rank: const {'k-audio': 0, 'k-part': 1},
      ),
      PlaylistEntry(id: audioId, kind: MaterialKind.audio),
    );
  });

  test('favorito ausente do praise cai no fallback fixo', () {
    expect(
      preferredEntryForPraise(index, '0a1', rank: const {'k-outro': 0}),
      PlaylistEntry(id: pdfId, kind: MaterialKind.pdf),
    );
  });

  test('praise só com áudio: o áudio', () {
    expect(
      preferredEntryForPraise(index, '0c3'),
      PlaylistEntry(id: onlyAudioId, kind: MaterialKind.audio),
    );
  });

  test('sem PDF nem áudio: a primeira cifra (antes dos gestos)', () {
    expect(
      preferredEntryForPraise(index, 'fff'),
      PlaylistEntry(id: chordId, kind: MaterialKind.chord),
    );
  });

  test('sem PDF, áudio nem cifra: o primeiro documento de gestos', () {
    expect(
      preferredEntryForPraise(index, '4d4'),
      PlaylistEntry(id: gestureId, kind: MaterialKind.gesture),
    );
  });

  test('praise só com letra → null', () {
    expect(preferredEntryForPraise(index, '5e5'), isNull);
  });

  test('token desconhecido → null', () {
    expect(preferredEntryForPraise(index, 'abc'), isNull);
  });
}
