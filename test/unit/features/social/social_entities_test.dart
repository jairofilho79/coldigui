import 'package:coldigui/features/social/domain/entities/public_playlist.dart';
import 'package:coldigui/features/social/domain/entities/social_user.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:flutter_test/flutter_test.dart';

final _pdfId = encodePdfId('ColAdultos/001.pdf');
final _chordId = encodePdfId('ColAdultos/001.chord');
final _audioId = encodePdfId('assets/praises/a/001.mp3');

void main() {
  test('SocialUser.fromJson', () {
    final user = SocialUser.fromJson({'username': 'maria', 'playlistCount': 3});
    expect(user.username, 'maria');
    expect(user.playlistCount, 3);
  });

  test('PublicPlaylist.fromJson ordena campos de publicação', () {
    final playlist = PublicPlaylist.fromJson({
      'id': 'p1',
      'nome': 'Culto',
      'pdfIds': ['a', 'b'],
      'publicationReach': 'usual',
      'publicationCategory': 'medleys',
      'publishedAt': '2026-07-01T00:00:00.000Z',
    });
    expect(playlist.pdfIds, ['a', 'b']);
    expect(playlist.audioIds, isEmpty);
    expect(playlist.publicationReach, PlaylistReach.usual);
    expect(playlist.publicationCategory, PlaylistCategory.medleys);
    expect(playlist.publishedAt?.isUtc, isTrue);
  });

  test('PublicPlaylist.fromJson v1 classifica entries pela extensão', () {
    final playlist = PublicPlaylist.fromJson({
      'id': 'p1',
      'nome': 'Culto',
      'pdfIds': [_pdfId, _chordId],
      'audioIds': [_audioId],
    });

    expect(playlist.entries.map((e) => e.kind), [
      MaterialKind.pdf,
      MaterialKind.chord,
      MaterialKind.audio,
    ]);
    expect(playlist.pdfIds, [_pdfId, _chordId]);
    expect(playlist.audioIds, [_audioId]);
  });

  test('PublicPlaylist.fromJson v2 preserva a ordem intercalada', () {
    final playlist = PublicPlaylist.fromJson({
      'id': 'p1',
      'nome': 'Culto',
      'items': [
        {'id': _audioId, 'kind': 'audio'},
        {'id': _pdfId, 'kind': 'pdf'},
      ],
      'pdfIds': [_pdfId],
      'audioIds': [_audioId],
    });

    expect(playlist.entries[0].id, _audioId);
    expect(playlist.entries[0].isAudio, isTrue);
    expect(playlist.entries[1].id, _pdfId);
    expect(playlist.entries[1].isAudio, isFalse);
  });
}
