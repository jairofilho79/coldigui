import 'package:coldigui/core/utils/playlist_share_url_builder.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_tab.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/exceptions/empty_playlist_share_exception.dart';
import 'package:coldigui/features/playlists/domain/exceptions/playlist_not_found_exception.dart';
import 'package:coldigui/features/playlists/domain/ports/share_link_shortener.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:coldigui/features/playlists/domain/usecases/generate_playlist_share_url.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeShortener implements ShareLinkShortener {
  _FakeShortener.ok(this._url) : _error = null;
  _FakeShortener.throwing(Object error) : _error = error, _url = null;

  final String? _url;
  final Object? _error;

  var callCount = 0;
  String? lastQuery;

  @override
  Future<String> shorten(String query) async {
    callCount++;
    lastQuery = query;
    final error = _error;
    if (error != null) throw error;
    return _url!;
  }
}

class _FakePlaylistRepository implements PlaylistRepository {
  _FakePlaylistRepository(this._playlists);

  final Map<String, SavedPlaylist> _playlists;

  @override
  Future<String> create({
    required String nome,
    List<PlaylistEntry>? entries,
    List<String> pdfIds = const [],
    List<String> audioIds = const [],
    String? playlistId,
    DateTime? createdAt,
    bool salva = true,
    DateTime? savedAt,
    DateTime? updatedAt,
    int version = 1,
    PlaylistSyncStatus syncStatus = PlaylistSyncStatus.synced,
    String? ownerSub,
  }) => throw UnimplementedError();

  @override
  Future<void> delete(String playlistId) => throw UnimplementedError();

  @override
  Future<void> deleteAllUnsaved() => throw UnimplementedError();

  @override
  Future<void> hardDelete(String playlistId) => throw UnimplementedError();

  @override
  Future<List<SavedPlaylist>> getAll() => throw UnimplementedError();

  @override
  Future<List<SavedPlaylist>> getByTab(PlaylistTab tab) =>
      throw UnimplementedError();

  @override
  Future<SavedPlaylist?> getById(String playlistId) async =>
      _playlists[playlistId];

  @override
  Future<List<SavedPlaylist>> getPendingPush({String? sub}) =>
      throw UnimplementedError();

  @override
  Future<List<SavedPlaylist>> getTombstones({String? sub}) =>
      throw UnimplementedError();

  @override
  Future<void> adoptForSub(String sub) => throw UnimplementedError();

  @override
  Future<int> purgeSyncedOwnedBy(String previousSub) =>
      throw UnimplementedError();

  @override
  Future<void> publish(
    String playlistId, {
    required PlaylistCategory category,
    PlaylistReach reach = PlaylistReach.usual,
  }) => throw UnimplementedError();

  @override
  Future<void> upsert(SavedPlaylist playlist) => throw UnimplementedError();

  @override
  Future<void> update(
    String playlistId, {
    String? nome,
    List<PlaylistEntry>? entries,
    List<String>? pdfIds,
    List<String>? audioIds,
    bool? salva,
    DateTime? savedAt,
    DateTime? favoritedAt,
    bool? favorita,
    bool clearFavoritedAt = false,
    DateTime? updatedAt,
    int? version,
    PlaylistSyncStatus? syncStatus,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => throw UnimplementedError();
}

void main() {
  const origin = 'https://plpcg.com';

  test('gera URL com pdfIds e nome da playlist', () async {
    final useCase = GeneratePlaylistShareUrl(
      _FakePlaylistRepository({
        'p1': SavedPlaylist.fromLegacyLists(
          playlistId: 'p1',
          nome: 'Ensaio',
          pdfIds: const ['a', 'b'],
          createdAt: DateTime(2026, 1, 1),
        ),
      }),
      shareOrigin: origin,
    );

    final link = await useCase(playlistId: 'p1');
    expect(link.isShort, isFalse);
    expect(link.url, contains('sharepdfs='));
    expect(link.url, contains('sharename='));
  });

  test('emite shareitems com a ordem intercalada da playlist', () async {
    const entries = [
      PlaylistEntry(id: 'pdf-a', kind: MaterialKind.pdf),
      PlaylistEntry(id: 'aud-1', kind: MaterialKind.audio),
      PlaylistEntry(id: 'cif-1', kind: MaterialKind.chord),
    ];
    final useCase = GeneratePlaylistShareUrl(
      _FakePlaylistRepository({
        'p1': SavedPlaylist(
          playlistId: 'p1',
          nome: 'Ensaio',
          entries: entries,
          createdAt: DateTime(2026, 1, 1),
        ),
      }),
      shareOrigin: origin,
    );

    final link = await useCase(playlistId: 'p1');
    final params = parsePlaylistShareParams(Uri.parse(link.url));
    expect(params!.entries, entries);
  });

  test('lança PlaylistNotFoundException quando ausente', () async {
    final useCase = GeneratePlaylistShareUrl(
      _FakePlaylistRepository({}),
      shareOrigin: origin,
    );

    expect(
      () => useCase(playlistId: 'missing'),
      throwsA(isA<PlaylistNotFoundException>()),
    );
  });

  test('lança EmptyPlaylistShareException quando pdfIds vazio', () async {
    final useCase = GeneratePlaylistShareUrl(
      _FakePlaylistRepository({
        'p1': SavedPlaylist.fromLegacyLists(
          playlistId: 'p1',
          nome: 'Vazia',
          pdfIds: const [],
          createdAt: DateTime(2026, 1, 1),
        ),
      }),
      shareOrigin: origin,
    );

    expect(
      () => useCase(playlistId: 'p1'),
      throwsA(isA<EmptyPlaylistShareException>()),
    );
  });

  group('link curto (D7)', () {
    GeneratePlaylistShareUrl useCaseWith(ShareLinkShortener? shortener) =>
        GeneratePlaylistShareUrl(
          _FakePlaylistRepository({
            'p1': SavedPlaylist.fromLegacyLists(
              playlistId: 'p1',
              nome: 'Ensaio',
              pdfIds: const ['a', 'b'],
              createdAt: DateTime(2026, 1, 1),
            ),
          }),
          shareOrigin: origin,
          shortener: shortener,
        );

    test('short: false não chama o shortener — devolve a URL longa', () async {
      final shortener = _FakeShortener.ok('https://plpcg.com/l/abc1234');
      final useCase = useCaseWith(shortener);

      final link = await useCase(playlistId: 'p1');

      expect(shortener.callCount, 0);
      expect(link.url, contains('sharepdfs='));
    });

    test('short: true com shortener ok devolve a URL curta', () async {
      final shortener = _FakeShortener.ok('https://plpcg.com/l/abc1234');
      final useCase = useCaseWith(shortener);

      final link = await useCase(playlistId: 'p1', short: true);

      expect(link.url, 'https://plpcg.com/l/abc1234');
      expect(shortener.callCount, 1);
      expect(shortener.lastQuery, contains('sharepdfs='));
      expect(shortener.lastQuery, isNot(contains('?')));
    });

    test('short: true com shortener que lança cai na URL longa', () async {
      final shortener = _FakeShortener.throwing(StateError('boom'));
      final useCase = useCaseWith(shortener);

      final link = await useCase(playlistId: 'p1', short: true);

      expect(link.url, contains('sharepdfs='));
      expect(link.url, startsWith(origin));
    });

    test('short: true sem shortener configurado devolve a URL longa', () async {
      final useCase = useCaseWith(null);

      final link = await useCase(playlistId: 'p1', short: true);

      expect(link.url, contains('sharepdfs='));
    });
  });

  group('formato curto (D7)', () {
    final repo = _FakePlaylistRepository({
      'p1': SavedPlaylist(
        playlistId: 'p1',
        nome: 'Culto de domingo',
        entries: const [
          PlaylistEntry(id: 'pdf-b', kind: MaterialKind.pdf),
          PlaylistEntry(id: 'pdf-a', kind: MaterialKind.pdf),
        ],
        createdAt: DateTime(2026, 1, 1),
      ),
      'mista': SavedPlaylist(
        playlistId: 'mista',
        nome: 'Mista',
        entries: const [
          PlaylistEntry(id: 'pdf-a', kind: MaterialKind.pdf),
          PlaylistEntry(id: 'aud-1', kind: MaterialKind.audio),
        ],
        createdAt: DateTime(2026, 1, 1),
      ),
    });
    String? lookup(String pdfId) =>
        const {'pdf-a': '0000', 'pdf-b': '1a2f'}[pdfId];

    test('todas as entradas PDF com shortId → link curto (vetor do contrato)', () async {
      final useCase = GeneratePlaylistShareUrl(repo, shareOrigin: origin, shortIdOf: lookup);
      final link = await useCase(playlistId: 'p1');
      expect(link.isShort, isTrue);
      expect(link.url, 'https://plpcg.com/?s=1a2f-0000&n=Culto%20de%20domingo');
    });

    test('lista com áudio → formato longo', () async {
      final useCase = GeneratePlaylistShareUrl(repo, shareOrigin: origin, shortIdOf: lookup);
      final link = await useCase(playlistId: 'mista');
      expect(link.isShort, isFalse);
      expect(link.url, contains('shareitems='));
    });

    test('PDF sem shortId no catálogo → formato longo', () async {
      final useCase = GeneratePlaylistShareUrl(
        repo, shareOrigin: origin, shortIdOf: (id) => id == 'pdf-a' ? '0000' : null,
      );
      final link = await useCase(playlistId: 'p1');
      expect(link.isShort, isFalse);
    });

    test('sem lookup (shortIdOf null) → formato longo', () async {
      final useCase = GeneratePlaylistShareUrl(repo, shareOrigin: origin);
      expect((await useCase(playlistId: 'p1')).isShort, isFalse);
    });

    test('short: true com link curto NÃO chama o encurtador /l/', () async {
      final shortener = _FakeShortener.ok('https://plpcg.com/l/abc');
      final useCase = GeneratePlaylistShareUrl(
        repo,
        shareOrigin: origin,
        shortIdOf: lookup,
        shortener: shortener,
      );
      final link = await useCase(playlistId: 'p1', short: true);
      expect(link.isShort, isTrue);
      expect(shortener.callCount, 0);
    });
  });
}
