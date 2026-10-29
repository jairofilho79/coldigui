import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/constants/offline_config.dart';
import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/database/isar_app_schemas.dart';
import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/ports/pdf_storage_port.dart';
import 'package:coldigui/features/offline/domain/usecases/migrate_offline_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
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

/// Isar com o schema real do app (o passo 5 mexe em `LouvorCache`), fechado
/// e apagado no teardown junto com [dir].
Isar _openIsar(Directory dir) {
  final isar = Isar.open(
    schemas: kAppIsarSchemas,
    directory: dir.path,
    name: 'migrate_${DateTime.now().microsecondsSinceEpoch}',
  );
  addTearDown(() async {
    isar.close(deleteFromDisk: true);
    if (dir.existsSync()) await dir.delete(recursive: true);
  });
  return isar;
}

/// Conta as limpezas do cache legado sem precisar de Isar.
class _RecordingLocalDatasource extends OfflinePdfLocalDatasource {
  _RecordingLocalDatasource() : super.unavailable();

  int legacyCatalogClears = 0;

  @override
  Future<void> clearLegacyCatalogCache() async => legacyCatalogClears++;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('v0 migra para versão atual', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = _TrackingPdfStoragePort();
    final isar = _openIsar(await Directory.systemTemp.createTemp('migrate_'));
    final useCase = MigrateOfflineStorage(
      prefs,
      OfflinePdfLocalDatasource(isar),
      store,
    );

    await useCase();

    expect(
      prefs.getInt(StorageKeys.offlineStorageVersion),
      OfflineConfig.offlineStorageVersion,
    );
    expect(store.purgeLegacyCalls, 1);
  });

  test('segunda execução é no-op', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      StorageKeys.offlineStorageVersion,
      OfflineConfig.offlineStorageVersion,
    );

    final store = _TrackingPdfStoragePort();
    final isar = _openIsar(await Directory.systemTemp.createTemp('migrate_'));
    final useCase = MigrateOfflineStorage(
      prefs,
      OfflinePdfLocalDatasource(isar),
      store,
    );
    await useCase();

    expect(
      prefs.getInt(StorageKeys.offlineStorageVersion),
      OfflineConfig.offlineStorageVersion,
    );
    expect(store.purgeLegacyCalls, 0);
  });

  test('v2 marca PDFs como persistentes quando offline configurado', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('OFFLINE_AVAILABLE', 'TRUE');

    final tempDir = await Directory.systemTemp.createTemp('migrate_v2_');
    final docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);
    final isar = _openIsar(tempDir);
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
      pdfStoragePortFor(
        PdfLocalStore(getApplicationDocumentsDirectory: () async => docsDir),
      ),
    );
    await useCase();

    final entry = await repository.findIndexEntry(
      encodePdfId('ColAdultos/a.pdf'),
    );
    expect(entry?.isPersistent, isTrue);
  });

  test('v3 chama purgeLegacyStorage ao migrar de v2', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.offlineStorageVersion, 2);

    final store = _TrackingPdfStoragePort();
    final isar = _openIsar(
      await Directory.systemTemp.createTemp('migrate_v3_'),
    );
    final useCase = MigrateOfflineStorage(
      prefs,
      OfflinePdfLocalDatasource(isar),
      store,
    );

    await useCase();

    expect(
      prefs.getInt(StorageKeys.offlineStorageVersion),
      OfflineConfig.offlineStorageVersion,
    );
    expect(store.purgeLegacyCalls, 1);
  });

  test(
    'v4 remove o checksum salvo ao migrar de v3 (força re-download do corpo)',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(StorageKeys.offlineStorageVersion, 3);
      await prefs.setString('manifestChecksum', 'checksum-antigo');

      final store = _TrackingPdfStoragePort();
      final isar = _openIsar(
        await Directory.systemTemp.createTemp('migrate_v4_'),
      );
      final useCase = MigrateOfflineStorage(
        prefs,
        OfflinePdfLocalDatasource(isar),
        store,
      );

      await useCase();

      expect(
        prefs.getInt(StorageKeys.offlineStorageVersion),
        OfflineConfig.offlineStorageVersion,
      );
      expect(prefs.getString('manifestChecksum'), isNull);
    },
  );

  test('versão atual mantém o checksum intacto (no-op)', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      StorageKeys.offlineStorageVersion,
      OfflineConfig.offlineStorageVersion,
    );
    await prefs.setString('manifestChecksum', 'checksum-atual');

    final store = _TrackingPdfStoragePort();
    final isar = _openIsar(
      await Directory.systemTemp.createTemp('migrate_v4_noop_'),
    );
    final useCase = MigrateOfflineStorage(
      prefs,
      OfflinePdfLocalDatasource(isar),
      store,
    );

    await useCase();

    expect(
      prefs.getInt(StorageKeys.offlineStorageVersion),
      OfflineConfig.offlineStorageVersion,
    );
    expect(prefs.getString('manifestChecksum'), 'checksum-atual');
  });

  test('v5 apaga as prefs mortas do manifesto e da secção PLPCG', () async {
    const dead = [
      'manifestChecksum',
      'catalogLastSyncAt',
      'lastChecksumPollAt',
      'offlineSelectedCategories',
      'offlineBulkCategories',
      'offlineBulkCheckpoint',
      'OFFLINE_AVAILABLE',
    ];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.offlineStorageVersion, 4);
    for (final key in dead) {
      await prefs.setString(key, 'x');
    }
    await prefs.setString(StorageKeys.recentlyOpened, '[]');

    final isar = _openIsar(
      await Directory.systemTemp.createTemp('migrate_v5_'),
    );
    await MigrateOfflineStorage(
      prefs,
      OfflinePdfLocalDatasource(isar),
      _TrackingPdfStoragePort(),
    )();

    expect(prefs.getInt(StorageKeys.offlineStorageVersion), 5);
    for (final key in dead) {
      expect(prefs.containsKey(key), isFalse, reason: key);
    }
    expect(
      prefs.getString(StorageKeys.recentlyOpened),
      '[]',
      reason: 'só as mortas saem',
    );
  });

  group('v5 apaga os dados da coleção LouvorCache', () {
    test('com Isar: esvazia a coleção e a versão sobe', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(StorageKeys.offlineStorageVersion, 4);
      final local = _RecordingLocalDatasource();

      await MigrateOfflineStorage(prefs, local, _TrackingPdfStoragePort())();

      expect(local.legacyCatalogClears, 1);
      expect(prefs.getInt(StorageKeys.offlineStorageVersion), 5);
    });

    test('sem Isar: limpa as prefs, lança e a versão fica em 4', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(StorageKeys.offlineStorageVersion, 4);
      await prefs.setString('manifestChecksum', 'x');

      await expectLater(
        MigrateOfflineStorage(
          prefs,
          const OfflinePdfLocalDatasource.unavailable(),
          _TrackingPdfStoragePort(),
        )(),
        throwsA(
          isA<StorageUnavailableException>().having(
            (e) => e.operation,
            'operation',
            'offline.migrateV5',
          ),
        ),
      );

      expect(prefs.getInt(StorageKeys.offlineStorageVersion), 4);
      expect(prefs.containsKey('manifestChecksum'), isFalse);
    });
  });
}
