import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/carousel/data/providers/carousel_providers.dart';
import 'package:coldigui/features/carousel/domain/repositories/carousel_repository.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_remote_datasource.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_tab.dart';
import 'package:coldigui/features/playlists/domain/entities/remote_playlist.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_sync.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_sync_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

class _LoggedInAuth extends AuthNotifier {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(googleSub: 'sub-1', idToken: 'token');
}

class _RecordingRemote extends PlaylistRemoteDatasource {
  _RecordingRemote() : super(Dio());

  var fetchCalls = 0;
  var upsertCalls = 0;

  @override
  Future<List<RemotePlaylist>> fetchAll(String idToken) async {
    fetchCalls++;
    return const [];
  }

  @override
  Future<RemotePlaylist> upsert({
    required String idToken,
    required RemotePlaylist playlist,
  }) async {
    upsertCalls++;
    return RemotePlaylist(
      id: playlist.id,
      nome: playlist.nome,
      pdfIds: playlist.pdfIds,
      audioIds: playlist.audioIds,
      salva: playlist.salva,
      favorita: playlist.favorita,
      createdAt: playlist.createdAt,
      updatedAt: playlist.updatedAt,
      version: playlist.version + 1,
      savedAt: playlist.savedAt,
      favoritedAt: playlist.favoritedAt,
    );
  }

  @override
  Future<void> softDelete({
    required String idToken,
    required String playlistId,
  }) async {}
}

class _FakeCarouselRepo extends Fake implements CarouselRepository {
  _FakeCarouselRepo(this.ids);

  final List<String> ids;

  @override
  Future<List<String>> getOrderedPdfIds() async => ids;
}

class _MemoryPlaylistRepository implements PlaylistRepository {
  final map = <String, SavedPlaylist>{};

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
  }) async {
    final id = playlistId ?? 'gen';
    final now = createdAt ?? DateTime.utc(2026, 1, 1);
    map[id] = SavedPlaylist(
      playlistId: id,
      nome: nome,
      pdfIds: pdfIds,
      audioIds: audioIds,
      createdAt: now,
      salva: salva,
      savedAt: savedAt ?? (salva ? now : null),
      updatedAt: updatedAt ?? now,
      version: version,
      syncStatus: salva ? PlaylistSyncStatus.pendingPush : syncStatus,
    );
    return id;
  }

  @override
  Future<void> delete(String playlistId) async {
    map.remove(playlistId);
  }

  @override
  Future<void> deleteAllUnsaved() async {
    map.removeWhere((_, p) => !p.salva);
  }

  @override
  Future<List<SavedPlaylist>> getAll() async =>
      map.values.where((p) => p.deletedAt == null).toList();

  @override
  Future<SavedPlaylist?> getById(String playlistId) async => map[playlistId];

  @override
  Future<List<SavedPlaylist>> getByTab(PlaylistTab tab) async => getAll();

  @override
  Future<List<SavedPlaylist>> getPendingPush() async => map.values
      .where(
        (p) =>
            p.salva &&
            p.deletedAt == null &&
            p.syncStatus == PlaylistSyncStatus.pendingPush,
      )
      .toList();

  @override
  Future<List<SavedPlaylist>> getTombstones() async => map.values
      .where(
        (p) =>
            p.deletedAt != null &&
            p.syncStatus == PlaylistSyncStatus.pendingPush,
      )
      .toList();

  @override
  Future<void> hardDelete(String playlistId) async {
    map.remove(playlistId);
  }

  @override
  Future<void> markAllSavedPendingPush() async {
    for (final e in map.entries.toList()) {
      if (e.value.salva && e.value.deletedAt == null) {
        map[e.key] = e.value.copyWith(
          syncStatus: PlaylistSyncStatus.pendingPush,
        );
      }
    }
  }

  @override
  Future<void> publish(
    String playlistId, {
    required PlaylistCategory category,
    PlaylistReach reach = PlaylistReach.usual,
  }) async {
    throw UnimplementedError();
  }

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
  }) async {
    final existing = map[playlistId];
    if (existing == null) throw StateError('missing');
    final becomesSaved = salva == true || existing.salva;
    final touchSync =
        nome != null ||
        pdfIds != null ||
        audioIds != null ||
        salva != null ||
        savedAt != null ||
        favoritedAt != null ||
        favorita != null ||
        clearFavoritedAt ||
        deletedAt != null;
    map[playlistId] = existing.copyWith(
      nome: nome,
      pdfIds: pdfIds,
      audioIds: audioIds,
      salva: salva,
      savedAt: savedAt,
      favoritedAt: clearFavoritedAt ? null : favoritedAt,
      favorita: favorita,
      updatedAt: updatedAt ?? (touchSync ? DateTime.utc(2026, 8, 19) : null),
      version: version,
      syncStatus:
          syncStatus ??
          (touchSync && becomesSaved ? PlaylistSyncStatus.pendingPush : null),
      deletedAt: deletedAt,
      clearDeletedAt: clearDeletedAt,
    );
  }

  @override
  Future<void> upsert(SavedPlaylist playlist) async {
    map[playlist.playlistId] = playlist;
  }
}

class _CarouselSyncRunner extends Notifier<int> {
  @override
  int build() => 0;

  Future<void> run() => syncActivePlaylistFromCarousel(ref);
}

final _carouselSyncRunnerProvider = NotifierProvider<_CarouselSyncRunner, int>(
  _CarouselSyncRunner.new,
);

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late SharedPreferences prefs;
  late _MemoryPlaylistRepository repo;
  late _RecordingRemote remote;

  setUp(() async {
    SharedPreferences.setMockInitialValues({kActivePlaylistIdPrefsKey: 'p1'});
    prefs = await SharedPreferences.getInstance();
    repo = _MemoryPlaylistRepository();
    remote = _RecordingRemote();
  });

  ProviderContainer _container({required List<String> carouselPdfIds}) {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(_LoggedInAuth.new),
        playlistRepositoryProvider.overrideWithValue(repo),
        playlistRemoteDatasourceProvider.overrideWithValue(remote),
        carouselRepositoryProvider.overrideWithValue(
          _FakeCarouselRepo(carouselPdfIds),
        ),
        louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
      ],
    );
  }

  test('lista salva dispara fetch remoto ao espelhar o carousel', () async {
    await repo.create(
      nome: 'Culto',
      pdfIds: const ['old'],
      playlistId: 'p1',
      salva: true,
    );
    final container = _container(carouselPdfIds: const ['old', 'new']);
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    await container.read(_carouselSyncRunnerProvider.notifier).run();
    await _flushAsync();

    expect(remote.fetchCalls, greaterThan(0));
    expect(remote.upsertCalls, greaterThan(0));
  });

  test('rascunho não dispara rede ao espelhar o carousel', () async {
    await repo.create(
      nome: 'Rascunho',
      pdfIds: const ['old'],
      playlistId: 'p1',
      salva: false,
    );
    final container = _container(carouselPdfIds: const ['old', 'new']);
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    await container.read(_carouselSyncRunnerProvider.notifier).run();
    await _flushAsync();

    expect(remote.fetchCalls, 0);
    expect(remote.upsertCalls, 0);
  });

  test('addAudio em lista salva dispara fetch remoto', () async {
    await repo.create(
      nome: 'Culto',
      pdfIds: const ['pdf-a'],
      audioIds: const [],
      playlistId: 'p1',
      salva: true,
    );
    final container = _container(carouselPdfIds: const ['pdf-a']);
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(playlistsProvider);
    await _flushAsync();
    await container
        .read(playlistsProvider.notifier)
        .addAudioToActivePlaylist('aud-1');
    await _flushAsync();

    expect(remote.fetchCalls, greaterThan(0));
    expect(remote.upsertCalls, greaterThan(0));
  });

  test('addAudio em rascunho não dispara rede', () async {
    await repo.create(
      nome: 'Rascunho',
      pdfIds: const ['pdf-a'],
      audioIds: const [],
      playlistId: 'p1',
      salva: false,
    );
    final container = _container(carouselPdfIds: const ['pdf-a']);
    addTearDown(container.dispose);

    await container.read(authStateProvider.future);
    container.read(playlistsProvider);
    await _flushAsync();
    await container
        .read(playlistsProvider.notifier)
        .addAudioToActivePlaylist('aud-1');
    await _flushAsync();

    expect(remote.fetchCalls, 0);
    expect(remote.upsertCalls, 0);
  });
}
