// O debounce do display saiu: a barra recebe a ordem nova na hora, pelo
// override otimista do `ActivePlaylistEditor`, e nunca vê a ordem antiga entre
// a escrita e o `reload` (D3). Estes testes fixam esse contrato.
import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/carousel/data/datasources/carousel_local_datasource.dart';
import 'package:coldigui/features/carousel/data/providers/carousel_providers.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_display_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

final _pdfA = encodePdfId('ColAdultos/001.pdf');
final _pdfB = encodePdfId('ColAdultos/002.pdf');

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late Directory tempDir;
  late Isar isar;
  late PlaylistRepositoryImpl repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('carousel_display_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    repository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<ProviderContainer> boot(List<String> ids) async {
    await repository.create(
      nome: 'Ativa',
      entries: [
        for (final id in ids) PlaylistEntry(id: id, kind: MaterialKind.pdf),
      ],
      playlistId: 'p1',
      salva: false,
    );
    SharedPreferences.setMockInitialValues({kActivePlaylistIdPrefsKey: 'p1'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        playlistRepositoryProvider.overrideWithValue(repository),
        carouselLocalDatasourceProvider.overrideWithValue(
          const CarouselLocalDatasource.unavailable(),
        ),
        louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
      ],
    );
    addTearDown(container.dispose);
    container.read(playlistsProvider);
    await _flush();
    return container;
  }

  test('display espelha a face de partituras da lista ativa', () async {
    final c = await boot([_pdfA]);

    expect(c.read(carouselLouvoresDisplayProvider).map((e) => e.materialId), [
      _pdfA,
    ]);

    await c.read(carouselLouvoresProvider.notifier).add(_pdfB);
    await _flush();

    expect(c.read(carouselLouvoresDisplayProvider).map((e) => e.materialId), [
      _pdfA,
      _pdfB,
    ]);
  });

  test('reorder aplica override otimista sem esperar debounce', () async {
    final c = await boot([_pdfA, _pdfB]);

    expect(c.read(carouselLouvoresDisplayProvider).map((e) => e.materialId), [
      _pdfA,
      _pdfB,
    ]);

    await c.read(carouselLouvoresProvider.notifier).reorder([_pdfB, _pdfA]);

    // Sem esperar nada: a nova ordem já está na view.
    expect(c.read(carouselLouvoresDisplayProvider).map((e) => e.materialId), [
      _pdfB,
      _pdfA,
    ]);

    await Future<void>.delayed(carouselReorderPersistDebounce * 3);
    await _flush();

    // E continua depois de persistir e recarregar.
    expect(c.read(carouselLouvoresDisplayProvider).map((e) => e.materialId), [
      _pdfB,
      _pdfA,
    ]);
    expect((await repository.getById('p1'))!.items, [_pdfB, _pdfA]);
  });
}
