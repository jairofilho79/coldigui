// test/unit/features/playlists/playlists_provider_boot_hydrate_test.dart
//
// Boot frio com o app montado durante a abertura do Isar (A8): a hidratação da
// sessão não pode rodar contra o datasource degradado — ele responde `[]`/`null`
// sem distinguir "não existe" de "o banco ainda não abriu", e `hydratePlaylistSession`
// grava essa conclusão nas SharedPreferences (apagando o id da playlist ativa).
import '../../../helpers/louvores_manifest_test_helpers.dart';
import '../../../support/fakes/fake_isar.dart';
import 'dart:async';
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/carousel/data/datasources/carousel_local_datasource.dart';
import 'package:coldigui/features/carousel/data/providers/carousel_providers.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_provider.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _playlist = SavedPlaylist.fromLegacyLists(
  playlistId: 'pl-1',
  nome: 'Ensaio',
  pdfIds: const [],
  audioIds: const [],
  createdAt: DateTime(2026, 1, 1),
);

/// Espelha `PlaylistLocalDatasource.unavailable()`: enquanto o Isar não abriu,
/// toda leitura responde vazio/`null` — igualzinho a um banco sem dados.
class _DegradedUntilOpenRepo extends Fake implements PlaylistRepository {
  _DegradedUntilOpenRepo(this._container);

  final ProviderContainer Function() _container;

  var getByIdCalls = 0;

  bool get _hasStorage =>
      _container().read(isarStatusProvider) == IsarStatus.available;

  @override
  Future<List<SavedPlaylist>> getAll() async =>
      _hasStorage ? [_playlist] : const [];

  @override
  Future<SavedPlaylist?> getById(String playlistId) async {
    getByIdCalls++;
    if (!_hasStorage) return null;
    return playlistId == _playlist.playlistId ? _playlist : null;
  }
}

Future<void> _flushAsync() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('boot durante a abertura do Isar não apaga a playlist ativa', () async {
    SharedPreferences.setMockInitialValues({
      kActivePlaylistIdPrefsKey: 'pl-1',
    });
    final prefs = await SharedPreferences.getInstance();

    final opening = Completer<Isar>();
    late ProviderContainer container;
    final repository = _DegradedUntilOpenRepo(() => container);

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarOpenerProvider.overrideWithValue(() => opening.future),
        playlistRepositoryProvider.overrideWithValue(repository),
        carouselLocalDatasourceProvider.overrideWithValue(
          CarouselLocalDatasource.unavailable(),
        ),
        louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
      ],
    );
    addTearDown(container.dispose);

    container.read(playlistsProvider);
    await _flushAsync();

    expect(
      container.read(playlistsProvider),
      isEmpty,
      reason: 'sem Isar o repositório degradado não tem o que listar',
    );
    expect(
      prefs.getString(kActivePlaylistIdPrefsKey),
      'pl-1',
      reason: 'o boot não pode apagar o id ativo enquanto o Isar abre',
    );
    opening.complete(FakeIsar());
    await _flushAsync();

    expect(
      container.read(playlistsProvider).map((i) => i.playlist.playlistId),
      ['pl-1'],
      reason: 'ao Isar abrir, a lista recarrega sozinha',
    );
    expect(container.read(activePlaylistIdProvider), 'pl-1');
    expect(prefs.getString(kActivePlaylistIdPrefsKey), 'pl-1');
    expect(
      repository.getByIdCalls,
      1,
      reason: 'a hidratação roda uma vez só, e com storage',
    );
  });

  test('Isar que nunca abre não hidrata nem toca nas prefs', () async {
    SharedPreferences.setMockInitialValues({
      kActivePlaylistIdPrefsKey: 'pl-1',
    });
    final prefs = await SharedPreferences.getInstance();

    late ProviderContainer container;
    final repository = _DegradedUntilOpenRepo(() => container);

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarOpenerProvider.overrideWithValue(
          () async => throw StateError('sem OPFS'),
        ),
        playlistRepositoryProvider.overrideWithValue(repository),
        carouselLocalDatasourceProvider.overrideWithValue(
          CarouselLocalDatasource.unavailable(),
        ),
        louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
      ],
    );
    addTearDown(container.dispose);

    container.read(playlistsProvider);
    await _flushAsync();

    expect(repository.getByIdCalls, 0);
    expect(prefs.getString(kActivePlaylistIdPrefsKey), 'pl-1');
  });
}
