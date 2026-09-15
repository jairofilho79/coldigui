import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/live/domain/live_coldigom_only.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final coldigomPdf = PlaylistEntry.classified(
    encodePdfId('assets/praises/p1/partitura.pdf'),
  );
  final coldigomAudio = PlaylistEntry.audio(
    encodePdfId('assets/praises/p1/voz.mp3'),
  );
  final coldigomGesture = PlaylistEntry.classified(
    encodePdfId('assets/praises/p1/gestos.gestures'),
  );
  const youtube = PlaylistEntry(id: 'yt-abc', kind: MaterialKind.youtube);
  final plpcgPdf = PlaylistEntry.classified(encodePdfId('ColAdultos/001.pdf'));
  final plpcgChord = PlaylistEntry.classified(encodePdfId('Cifras/001.chord'));

  test('lista só com materiais Coldigom passa', () {
    expect(
      nonColdigomEntries([
        coldigomPdf,
        coldigomAudio,
        coldigomGesture,
        youtube,
      ]),
      isEmpty,
    );
    expect(nonColdigomEntries(const []), isEmpty);
  });

  test('devolve só as entradas fora do Coldigom, na ordem', () {
    expect(
      nonColdigomEntries([coldigomPdf, plpcgPdf, coldigomAudio, plpcgChord]),
      [plpcgPdf, plpcgChord],
    );
  });

  test('id que não decodifica conta como fora do Coldigom', () {
    const broken = PlaylistEntry(id: '???', kind: MaterialKind.unknown);
    expect(nonColdigomEntries([broken]), [broken]);
    expect(isColdigomEntry(broken), isFalse);
    expect(isColdigomEntry(youtube), isTrue);
  });
}
