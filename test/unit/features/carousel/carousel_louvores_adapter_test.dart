// O adaptador `carouselLouvoresProvider` fala em `pdfId`, mas a lista ativa é
// endereçada por chave de ocorrência. Estes testes fixam que a chave é sempre
// resolvida **na face de partituras** que o adaptador serve — nunca por
// `entryKeyFor(id, 0)`, que é a primeira ocorrência na ordem única e pode ser a
// entrada de áudio quando o mesmo id está nas duas faces.
import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/carousel/data/datasources/carousel_local_datasource.dart';
import 'package:coldigui/features/carousel/data/providers/carousel_providers.dart';
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

/// Um id que o Worker declarou como áudio **e** que também está na face de
/// partituras — é o caso em que `entryKeyFor(id, 0)` aponta para a ocorrência
/// errada.
final _ambiguo = encodePdfId('ColAdultos/001.pdf');
final _pdfB = encodePdfId('ColAdultos/002.pdf');
final _pdfC = encodePdfId('ColAdultos/003.pdf');

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
    tempDir = await Directory.systemTemp.createTemp('carousel_adapter_');
    isar = Isar.open(schemas: [PlaylistSchema], directory: tempDir.path);
    repository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<ProviderContainer> boot(List<PlaylistEntry> entries) async {
    await repository.create(
      nome: 'Ativa',
      entries: entries,
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

  /// Áudio primeiro: na ordem única, a **primeira** ocorrência do id é a de
  /// áudio, e a de partitura é a segunda (chave `id#1`).
  List<PlaylistEntry> idNasDuasFaces() => [
    PlaylistEntry(id: _ambiguo, kind: MaterialKind.audio),
    PlaylistEntry(id: _ambiguo, kind: MaterialKind.pdf),
    PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf),
  ];

  test(
    'remove tira a ocorrência da face de partituras, não a de áudio',
    () async {
      final c = await boot(idNasDuasFaces());

      await c.read(carouselLouvoresProvider.notifier).remove(_ambiguo);
      await _flush();

      final saved = await repository.getById('p1');
      expect(saved!.audioIds, [_ambiguo]);
      expect(saved.pdfIds, [_pdfB]);
      expect(c.read(carouselLouvoresProvider).map((i) => i.materialId), [
        _pdfB,
      ]);
    },
  );

  test('replacePdfId troca a ocorrência da face de partituras', () async {
    final c = await boot(idNasDuasFaces());

    final replaced = await c
        .read(carouselLouvoresProvider.notifier)
        .replacePdfId(_ambiguo, _pdfC);
    await _flush();

    expect(replaced, isTrue);
    final saved = await repository.getById('p1');
    expect(saved!.audioIds, [_ambiguo]);
    expect(saved.pdfIds, [_pdfC, _pdfB]);
  });

  test('reorder permuta só a face de partituras', () async {
    final c = await boot(idNasDuasFaces());

    await c.read(carouselLouvoresProvider.notifier).reorder([_pdfB, _ambiguo]);
    await Future<void>.delayed(carouselReorderPersistDebounce * 3);
    await _flush();

    final saved = await repository.getById('p1');
    expect(saved!.pdfIds, [_pdfB, _ambiguo]);
    expect(saved.audioIds, [_ambiguo]);
  });

  test('reorder consome uma chave por ocorrência repetida', () async {
    final c = await boot([
      PlaylistEntry(id: _ambiguo, kind: MaterialKind.pdf),
      PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf),
      PlaylistEntry(id: _ambiguo, kind: MaterialKind.pdf),
    ]);

    await c.read(carouselLouvoresProvider.notifier).reorder([
      _ambiguo,
      _ambiguo,
      _pdfB,
    ]);
    await Future<void>.delayed(carouselReorderPersistDebounce * 3);
    await _flush();

    expect((await repository.getById('p1'))!.pdfIds, [
      _ambiguo,
      _ambiguo,
      _pdfB,
    ]);
  });

  test('remove de id ausente da face não mexe na lista', () async {
    final c = await boot([PlaylistEntry(id: _pdfB, kind: MaterialKind.pdf)]);

    await c.read(carouselLouvoresProvider.notifier).remove(_pdfC);
    await _flush();

    expect((await repository.getById('p1'))!.pdfIds, [_pdfB]);
  });
}
