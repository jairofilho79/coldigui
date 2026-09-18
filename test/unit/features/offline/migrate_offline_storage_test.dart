import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/constants/offline_config.dart';
import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/features/offline/data/datasources/offline_available_store.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/ports/pdf_storage_port.dart';
import 'package:coldigui/features/offline/domain/usecases/migrate_offline_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_test_helpers.dart';

class _TrackingPdfStoragePort implements PdfStoragePort {
  int purgeLegacyCalls = 0;

  @override
  Future<String> get rootPath async => OfflineConfig.pdfStorageSubdir;

  @override
  Future<String> writeAtomic(Uint8List bytes, String relPath) async =>
      '${OfflineConfig.pdfStorageSubdir}/$relPath';

  @override
  Future<bool> exists(String storageKey) async => false;

  @override
  Future<void> delete(String storageKey) async {}

  @override
  Future<void> deleteTree() async {}

  @override
  Future<int> getTotalOfflineBytes() async => 0;

  @override
  Future<List<String>> listOrphans(Set<String> indexedStorageKeys) async =>
      const [];

  @override
  Future<Uint8List?> readBytes(String storageKey, {int? maxBytes}) async =>
      null;

  @override
  Future<void> purgeLegacyStorage() async {
    purgeLegacyCalls++;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('v0 migra para versão atual', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = _TrackingPdfStoragePort();
    final isar = openOfflineTestIsar(
      await Directory.systemTemp.createTemp('migrate_'),
    );
    final useCase = MigrateOfflineStorage(
      prefs,
      OfflinePdfLocalDatasource(isar),
      OfflineAvailableStore(prefs),
      store,
    );

    await useCase();

    expect(
      prefs.getInt(StorageKeys.offlineStorageVersion),
      OfflineConfig.offlineStorageVersion,
    );
    expect(store.purgeLegacyCalls, 1);
    isar.close(deleteFromDisk: true);
  });

  test('segunda execução é no-op', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      StorageKeys.offlineStorageVersion,
      OfflineConfig.offlineStorageVersion,
    );

    final store = _TrackingPdfStoragePort();
    final isar = openOfflineTestIsar(
      await Directory.systemTemp.createTemp('migrate_'),
    );
    final useCase = MigrateOfflineStorage(
      prefs,
      OfflinePdfLocalDatasource(isar),
      OfflineAvailableStore(prefs),
      store,
    );
    await useCase();

    expect(
      prefs.getInt(StorageKeys.offlineStorageVersion),
      OfflineConfig.offlineStorageVersion,
    );
    expect(store.purgeLegacyCalls, 0);
    isar.close(deleteFromDisk: true);
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
      pdfStoragePortFor(
        PdfLocalStore(getApplicationDocumentsDirectory: () async => docsDir),
      ),
    );
    await useCase();

    final entry = await repository.findIndexEntry(
      encodePdfId('ColAdultos/a.pdf'),
    );
    expect(entry?.isPersistent, isTrue);

    isar.close(deleteFromDisk: true);
  });

  test('v3 chama purgeLegacyStorage ao migrar de v2', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.offlineStorageVersion, 2);

    final store = _TrackingPdfStoragePort();
    final isar = openOfflineTestIsar(
      await Directory.systemTemp.createTemp('migrate_v3_'),
    );
    final useCase = MigrateOfflineStorage(
      prefs,
      OfflinePdfLocalDatasource(isar),
      OfflineAvailableStore(prefs),
      store,
    );

    await useCase();

    expect(
      prefs.getInt(StorageKeys.offlineStorageVersion),
      OfflineConfig.offlineStorageVersion,
    );
    expect(store.purgeLegacyCalls, 1);
    isar.close(deleteFromDisk: true);
  });

  test(
    'v4 remove o checksum salvo ao migrar de v3 (força re-download do corpo)',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(StorageKeys.offlineStorageVersion, 3);
      await prefs.setString(StorageKeys.manifestChecksum, 'checksum-antigo');

      final store = _TrackingPdfStoragePort();
      final isar = openOfflineTestIsar(
        await Directory.systemTemp.createTemp('migrate_v4_'),
      );
      final useCase = MigrateOfflineStorage(
        prefs,
        OfflinePdfLocalDatasource(isar),
        OfflineAvailableStore(prefs),
        store,
      );

      await useCase();

      expect(
        prefs.getInt(StorageKeys.offlineStorageVersion),
        OfflineConfig.offlineStorageVersion,
      );
      expect(prefs.getString(StorageKeys.manifestChecksum), isNull);
      isar.close(deleteFromDisk: true);
    },
  );

  test('v4 já migrado mantém o checksum intacto (no-op)', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      StorageKeys.offlineStorageVersion,
      OfflineConfig.offlineStorageVersion,
    );
    await prefs.setString(StorageKeys.manifestChecksum, 'checksum-atual');

    final store = _TrackingPdfStoragePort();
    final isar = openOfflineTestIsar(
      await Directory.systemTemp.createTemp('migrate_v4_noop_'),
    );
    final useCase = MigrateOfflineStorage(
      prefs,
      OfflinePdfLocalDatasource(isar),
      OfflineAvailableStore(prefs),
      store,
    );

    await useCase();

    expect(
      prefs.getInt(StorageKeys.offlineStorageVersion),
      OfflineConfig.offlineStorageVersion,
    );
    expect(prefs.getString(StorageKeys.manifestChecksum), 'checksum-atual');
    isar.close(deleteFromDisk: true);
  });
}
