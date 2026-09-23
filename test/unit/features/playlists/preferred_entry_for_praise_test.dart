import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/utils/preferred_entry_for_praise.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/praise_share_fixtures.dart';

void main() {
  final pdfId = praiseMaterialId('p1', 'partitura.pdf');
  final audioId = praiseMaterialId('p1', 'audio.mp3');
  final onlyAudioId = praiseMaterialId('p2', 'audio.mp3');
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
      chords: [
        praiseChord(
          praiseId: 'p3',
          chordId: praiseMaterialId('p3', 'cifra.chord'),
        ),
      ],
    ),
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

  test('praise sem nada adicionável (só cifra) → null', () {
    expect(preferredEntryForPraise(index, 'fff'), isNull);
  });

  test('token desconhecido → null', () {
    expect(preferredEntryForPraise(index, 'abc'), isNull);
  });
}
