import 'package:coldigui/features/social/domain/entities/public_playlist.dart';
import 'package:coldigui/features/social/domain/entities/social_user.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
