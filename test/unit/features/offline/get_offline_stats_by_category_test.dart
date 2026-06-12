import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/database/collections/louvor_cache.dart';
import 'package:coldigui/features/catalog/data/datasources/catalog_local_datasource.dart';
import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/offline/data/datasources/offline_manifest_remote_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/entities/offline_manifest.dart';
import 'package:coldigui/features/offline/domain/usecases/get_offline_stats_by_category.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'offline_test_helpers.dart';

class _FakeManifestDatasource extends OfflineManifestRemoteDatasource {
  _FakeManifestDatasource(this._manifest) : super(Dio());

  final OfflineManifest _manifest;

  @override
  Future<OfflineManifest> fetchManifest() async => _manifest;
}

void main() {
  late Isar isar;
  late OfflinePdfRepositoryImpl repository;
  late CatalogLocalDatasource catalogLocal;
  late GetOfflineStatsByCategory useCase;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('offline_stats_');
    final docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);

    isar = await openOfflineCatalogTestIsar(tempDir);
    final store = PdfLocalStore(
      getApplicationDocumentsDirectory: () async => docsDir,
    );
    repository = OfflinePdfRepositoryImpl(
      store: store,
      local: OfflinePdfLocalDatasource(isar),
    );
    catalogLocal = CatalogLocalDatasource(isar);
    useCase = GetOfflineStatsByCategory(
      repository,
      catalogLocal,
      _FakeManifestDatasource(
        const OfflineManifest(
          version: '1',
          packages: {
            CatalogMaterials.partitura: OfflineMaterialPackage(
              parts: [
                OfflinePackagePart(
                  filename: 'p.zip',
                  size: 1,
                  url: 'https://example.com/p.zip',
                  pdfs: ['missing-partitura'],
                ),
              ],
              totalSize: 1,
              totalParts: 1,
            ),
          },
        ),
      ),
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  Future<void> seedLouvor({
    required String pdfId,
    required String categoria,
  }) async {
    await isar.writeTxn(() async {
      await isar.louvorCaches.put(
        LouvorCache()
          ..pdfId = pdfId
          ..nome = 'Teste'
          ..numero = '001'
          ..categoria = categoria
          ..classificacao = 'ColAdultos'
          ..pdf = '001.pdf',
      );
    });
  }

  test('agrega contagem por material de UI via catálogo local', () async {
    final partituraId = encodePdfId('ColAdultos/a.pdf');
    final cifraId = encodePdfId('ColAdultos/b.pdf');

    await seedLouvor(
      pdfId: partituraId,
      categoria: CatalogMaterials.partitura,
    );
    await seedLouvor(
      pdfId: cifraId,
      categoria: CatalogMaterials.cifraNivelI,
    );

    await repository.upsert(
      pdfId: partituraId,
      bytes: Uint8List.fromList([1]),
      category: 'ColAdultos',
    );
    await repository.upsert(
      pdfId: cifraId,
      bytes: Uint8List.fromList([1]),
      category: 'ColAdultos',
    );

    final stats = await useCase();

    expect(stats.byCategory[CatalogMaterials.partitura], 1);
    expect(stats.byCategory[CatalogMaterials.cifra], 1);
    expect(stats.totalCount, 2);
    expect(stats.missingByCategory[CatalogMaterials.partitura], 1);
  });
}
