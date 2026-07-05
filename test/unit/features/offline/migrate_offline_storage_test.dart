import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/constants/offline_config.dart';
import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/features/offline/data/datasources/offline_available_store.dart';
import 'package:coldigui/features/offline/data/datasources/offline_manifest_remote_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/models/offline_manifest_dto.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/entities/offline_manifest.dart';
import 'package:coldigui/features/offline/domain/usecases/migrate_offline_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('v0 migra para versão atual', () async {
    final prefs = await SharedPreferences.getInstance();
    final isar = openOfflineTestIsar(
      await Directory.systemTemp.createTemp('migrate_'),
    );
    final useCase = MigrateOfflineStorage(
      prefs,
      OfflinePdfLocalDatasource(isar),
      OfflineAvailableStore(prefs),
    );

    await useCase();

    expect(
      prefs.getInt(StorageKeys.offlineStorageVersion),
      OfflineConfig.offlineStorageVersion,
    );
    isar.close(deleteFromDisk: true);
  });

  test('segunda execução é no-op', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      StorageKeys.offlineStorageVersion,
      OfflineConfig.offlineStorageVersion,
    );

    final isar = openOfflineTestIsar(
      await Directory.systemTemp.createTemp('migrate_'),
    );
    final useCase = MigrateOfflineStorage(
      prefs,
      OfflinePdfLocalDatasource(isar),
      OfflineAvailableStore(prefs),
    );
    await useCase();

    expect(
      prefs.getInt(StorageKeys.offlineStorageVersion),
      OfflineConfig.offlineStorageVersion,
    );
    isar.close(deleteFromDisk: true);
  });

  test('fetchManifest usa manifest persistido quando rede falha', () async {
    final prefs = await SharedPreferences.getInstance();
    const manifest = OfflineManifest(
      version: '1',
      packages: {
        'Partitura': OfflineMaterialPackage(
          parts: [
            OfflinePackagePart(
              filename: 'p.zip',
              size: 1,
              url: 'https://example.com/p.zip',
              pdfs: ['abc'],
            ),
          ],
          totalSize: 1,
          totalParts: 1,
        ),
      },
    );

    await prefs.setString(
      StorageKeys.offlineManifestJson,
      jsonEncode(OfflineManifestDto.toJson(manifest)),
    );

    final datasource = OfflineManifestRemoteDatasource(
      Dio(),
      prefs,
      networkOverride: () async {
        throw DioException.connectionError(
          requestOptions: RequestOptions(path: '/offline-manifest.json'),
          reason: 'offline',
        );
      },
    );
    final loaded = await datasource.fetchManifest();

    expect(loaded.version, '1');
    expect(loaded.packages['Partitura']?.totalParts, 1);
  });

  test('v2 marca PDFs como persistentes quando offline configurado', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.offlineAvailable, 'TRUE');

    final tempDir = await Directory.systemTemp.createTemp('migrate_v2_');
    final docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);
    final isar = openOfflineTestIsar(tempDir);
    final repository = OfflinePdfRepositoryImpl(
      store: pdfStoragePortFor(
        PdfLocalStore(getApplicationDocumentsDirectory: () async => docsDir),
      ),
      local: OfflinePdfLocalDatasource(isar),
    );

    await repository.upsert(
      pdfId: encodePdfId('ColAdultos/a.pdf'),
      bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
      category: 'ColAdultos',
    );

    final useCase = MigrateOfflineStorage(
      prefs,
      OfflinePdfLocalDatasource(isar),
      OfflineAvailableStore(prefs),
    );
    await useCase();

    final entry = await repository.findIndexEntry(
      encodePdfId('ColAdultos/a.pdf'),
    );
    expect(entry?.isPersistent, isTrue);

    isar.close(deleteFromDisk: true);
  });
}
