import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import '../../../helpers/louvores_manifest_test_helpers.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_share_option.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:coldigui/features/playlists/domain/usecases/generate_playlist_share_url.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_share_actions_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlaylistRepository implements PlaylistRepository {
  @override
  Future<SavedPlaylist?> getById(String playlistId) async {
    return SavedPlaylist(
      playlistId: playlistId,
      nome: 'Ensaio',
      pdfIds: const ['pdf-a'],
      createdAt: DateTime(2026, 6, 8),
    );
  }

  @override
  Future<String> create({
    required String nome,
    required List<String> pdfIds,
    List<String> audioIds = const [],
    String? playlistId,
    DateTime? createdAt,
    bool salva = true,
    DateTime? savedAt,
    DateTime? updatedAt,
    int version = 1,
    PlaylistSyncStatus syncStatus = PlaylistSyncStatus.synced,
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
  Future<List<SavedPlaylist>> getByTab(tab) => throw UnimplementedError();

  @override
  Future<List<SavedPlaylist>> getPendingPush() => throw UnimplementedError();

  @override
  Future<List<SavedPlaylist>> getTombstones() => throw UnimplementedError();

  @override
  Future<void> markAllSavedPendingPush() => throw UnimplementedError();

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
  const shareContext = PlaylistShareContext(
    playlistId: 'p1',
    nome: 'Ensaio',
    pdfIds: ['pdf-a'],
  );

  testWidgets('link only chama Share.share com URL', (tester) async {
    String? sharedText;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playlistRepositoryProvider.overrideWithValue(
            _FakePlaylistRepository(),
          ),
          generatePlaylistShareUrlProvider.overrideWithValue(
            GeneratePlaylistShareUrl(
              _FakePlaylistRepository(),
              shareOrigin: 'https://plpcg.com',
            ),
          ),
          louvoresManifestOverride(
            LouvoresManifest.fromLouvores([
              Louvor.fromManifest(
                nome: 'Louvor A',
                numero: '001',
                categoria: 'Partitura',
                classificacao: 'ColAdultos',
                pdf: 'a.pdf',
                pdfId: 'pdf-a',
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(body: SizedBox()),
        ),
      ),
    );

    final context = tester.element(find.byType(Scaffold));
    final container = ProviderScope.containerOf(context);
    final notifier = container.read(playlistShareActionsProvider.notifier);

    final ok = await notifier.share(
      context,
      shareContext,
      PlaylistShareOption.link,
      sharePositionOrigin: null,
      share: (text, {subject, sharePositionOrigin}) async {
        sharedText = text;
      },
    );

    expect(ok, isTrue);
    expect(sharedText, 'https://plpcg.com/?sharepdfs=pdf-a&sharename=Ensaio');
  });
}
