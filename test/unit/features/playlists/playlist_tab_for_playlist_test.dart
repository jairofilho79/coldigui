import 'package:coldigui/features/playlists/domain/entities/playlist_tab.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = SavedPlaylist(
    playlistId: 'p1',
    nome: 'Lista',
    pdfIds: const ['a'],
    createdAt: DateTime(2026, 1, 1),
  );

  test('forPlaylist retorna unsaved quando não salva', () {
    expect(
      PlaylistTabForPlaylist.forPlaylist(base.copyWith(salva: false)),
      PlaylistTab.unsaved,
    );
  });

  test('forPlaylist retorna saved quando salva e não favorita', () {
    expect(PlaylistTabForPlaylist.forPlaylist(base), PlaylistTab.saved);
  });

  test('forPlaylist retorna favorites quando favorita', () {
    expect(
      PlaylistTabForPlaylist.forPlaylist(
        base.copyWith(salva: true, favorita: true),
      ),
      PlaylistTab.favorites,
    );
  });
}
