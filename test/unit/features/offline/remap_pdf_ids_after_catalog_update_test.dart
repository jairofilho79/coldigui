import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/database/collections/carousel_entry.dart';
import 'package:coldigui/core/database/collections/louvor_cache.dart';
import 'package:coldigui/core/database/collections/offline_pdf_index.dart';
import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/features/carousel/data/datasources/carousel_local_datasource.dart';
import 'package:coldigui/features/carousel/data/repositories/carousel_repository_impl.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/usecases/remap_pdf_ids_after_catalog_update.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/playlists/data/repositories/playlist_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

String _encodePdfId(String path) {
  return base64Url
      .encode(utf8.encode(path))
      .replaceAll('+', '-')
      .replaceAll('/', '_')
      .replaceAll('=', '');
}

Louvor _louvor({
  required String pdfId,
  String groupId = '003:clamo-a-ti',
}) {
  return Louvor.fromManifest(
    nome: 'Clamo a ti',
    numero: '3',
    categoria: 'Partitura',
    classificacao: 'ColAdultos',
    pdf: '$pdfId.pdf',
    pdfId: pdfId,
    groupId: groupId,
  );
}

void main() {
  late Directory tempDir;
  late Directory docsDir;
  late Isar isar;
  late OfflinePdfRepositoryImpl offlineRepository;
  late PlaylistRepositoryImpl playlistRepository;
  late CarouselRepositoryImpl carouselRepository;

  const category = 'ColAdultos';
  const oldRelPath = 'ColAdultos/old.pdf';
  const newRelPath = 'ColAdultos/new.pdf';
  late String oldPdfId;
  late String newPdfId;

  setUpAll(() async {
    oldPdfId = _encodePdfId(oldRelPath);
    newPdfId = _encodePdfId(newRelPath);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('remap_pdf_ids_');
    docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);

    isar = Isar.open(schemas: [
        LouvorCacheSchema,
        OfflinePdfIndexSchema,
        PlaylistSchema,
        CarouselEntrySchema,
      ],
      directory: tempDir.path,
    );

    final store = PdfLocalStore(
      getApplicationDocumentsDirectory: () async => docsDir,
    );
    offlineRepository = OfflinePdfRepositoryImpl(
      store: store,
      local: OfflinePdfLocalDatasource(isar),
    );
    playlistRepository = PlaylistRepositoryImpl(PlaylistLocalDatasource(isar));
    carouselRepository = CarouselRepositoryImpl(CarouselLocalDatasource(isar));
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('remapPdfId reindexa arquivo existente sob novo pdfId', () async {
    final bytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
    final entry = await offlineRepository.upsert(
      pdfId: oldPdfId,
      bytes: bytes,
      category: category,
      isPersistent: true,
    );

    await offlineRepository.remapPdfId(
      fromPdfId: oldPdfId,
      toPdfId: newPdfId,
    );

    expect(await offlineRepository.lookup(oldPdfId), isNull);
    final remapped = await offlineRepository.lookup(newPdfId);
    expect(remapped, isNotNull);
    expect(remapped!.absolutePath, entry.absolutePath);
    expect(remapped.isPersistent, isTrue);
    expect(await File(entry.absolutePath).exists(), isTrue);
  });

  test('RemapPdfIdsAfterCatalogUpdate atualiza offline, playlist e carousel',
      () async {
    final bytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
    await offlineRepository.upsert(
      pdfId: oldPdfId,
      bytes: bytes,
      category: category,
      isPersistent: true,
    );

    final playlistId = await playlistRepository.create(
      nome: 'Ensaio',
      pdfIds: [oldPdfId, _encodePdfId('ColAdultos/other.pdf')],
    );
    await carouselRepository.replaceAll([oldPdfId]);

    final remap = RemapPdfIdsAfterCatalogUpdate(
      offlineRepository,
      playlistRepository,
      carouselRepository,
    );

    await remap(
      previousLouvores: [_louvor(pdfId: oldPdfId)],
      newLouvores: [_louvor(pdfId: newPdfId)],
    );

    expect(await offlineRepository.lookup(newPdfId), isNotNull);
    final playlist = await playlistRepository.getById(playlistId);
    expect(playlist!.pdfIds, [newPdfId, _encodePdfId('ColAdultos/other.pdf')]);
    expect(await carouselRepository.getOrderedPdfIds(), [newPdfId]);
  });
}
