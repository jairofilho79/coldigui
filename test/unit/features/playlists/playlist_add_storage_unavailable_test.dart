// test/unit/features/playlists/playlist_add_storage_unavailable_test.dart
//
// A1: adicionar à lista ativa nunca pode estourar `StorageUnavailableException`
// para o chamador — os `add*ToActivePlaylist` são disparados de futuros não
// aguardados (ex.: `playAudioInSession`), onde uma exceção vira erro assíncrono
// não tratado e o usuário não recebe nada.
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/carousel/data/datasources/carousel_local_datasource.dart';
import 'package:coldigui/features/carousel/data/providers/carousel_providers.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/legacy_ids_normalizer_test_helpers.dart';

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final _pdfA = encodePdfId('ColAdultos/001.pdf');
final _audioA = encodePdfId('assets/praises/a/002.mp3');

void main() {
  late SharedPreferences prefs;
  late PlaylistRepositoryImpl repository;

  setUp(() async {
    // Isar ausente: leituras devolvem vazio, escritas lançam.
    repository = PlaylistRepositoryImpl(
      const PlaylistLocalDatasource.unavailable(),
    );
    SharedPreferences.setMockInitialValues({kActivePlaylistIdPrefsKey: 'p1'});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer container() {
    return ProviderContainer(
      overrides: [
        noOpLegacyMaterialIdsNormalizerOverride(),
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarStatusProvider.overrideWithValue(IsarStatus.unavailable),
        playlistRepositoryProvider.overrideWithValue(repository),
        carouselLocalDatasourceProvider.overrideWithValue(
          const CarouselLocalDatasource.unavailable(),
        ),
      ],
    );
  }

  test(
    'addAudioToActivePlaylist sem storage devolve false em vez de lançar',
    () async {
      final c = container();
      addTearDown(c.dispose);
      c.read(playlistsProvider);
      await _flushAsync();

      final added = await c
          .read(playlistsProvider.notifier)
          .addAudioToActivePlaylist(_audioA);

      expect(added, isFalse);
    },
  );

  test(
    'addLouvorToActivePlaylist sem storage devolve false em vez de lançar',
    () async {
      final c = container();
      addTearDown(c.dispose);
      c.read(playlistsProvider);
      await _flushAsync();

      final added = await c
          .read(playlistsProvider.notifier)
          .addLouvorToActivePlaylist(_pdfA);

      expect(added, isFalse);
    },
  );
}
