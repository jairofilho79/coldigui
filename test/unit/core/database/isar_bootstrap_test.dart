import 'dart:io';

import 'package:archive/archive.dart';
import 'package:coldigui/core/database/collections/audio_flag.dart';
import 'package:coldigui/core/database/collections/carousel_entry.dart';
import 'package:coldigui/core/database/collections/chord_content_cache.dart';
import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/core/database/collections/gesture_dictionary_cache.dart';
import 'package:coldigui/core/database/collections/gesture_document_cache.dart';
import 'package:coldigui/core/database/collections/louvor_cache.dart';
import 'package:coldigui/core/database/collections/offline_audio_index.dart';
import 'package:coldigui/core/database/collections/offline_pdf_index.dart';
import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/database/isar_app_schemas.dart';
import 'package:coldigui/core/database/isar_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

void main() {
  Directory? tempDir;
  Isar? isar;

  tearDown(() async {
    if (isar != null && isar!.isOpen) {
      isar!.close(deleteFromDisk: true);
    }
    isar = null;
    if (tempDir != null && tempDir!.existsSync()) {
      await tempDir!.delete(recursive: true);
    }
    tempDir = null;
  });

  test('openAppIsar opens app schemas (native VM smoke)', () async {
    tempDir = await Directory.systemTemp.createTemp('isar_bootstrap_');
    final instanceName = 'bootstrap_${tempDir!.path.hashCode}';

    isar = await openAppIsar(name: instanceName, directory: tempDir!.path);

    expect(isar!.isOpen, isTrue);
    expect(kAppIsarSchemas.length, 10);

    isar!.write((isar) {
      expect(isar.louvorCaches, isNotNull);
      expect(isar.carouselEntrys, isNotNull);
      expect(isar.playlists, isNotNull);
      expect(isar.offlinePdfIndexs, isNotNull);
      expect(isar.offlineAudioIndexs, isNotNull);
      expect(isar.audioFlags, isNotNull);
      expect(isar.chordContentCaches, isNotNull);
      expect(isar.gestureDocumentCaches, isNotNull);
      expect(isar.gestureDictionaryCaches, isNotNull);
      expect(isar.coldigomPraiseCaches, isNotNull);
    });
  });

  test(
    'reopening preserves playlists, offline index and downloaded files',
    () async {
      tempDir = await Directory.systemTemp.createTemp('isar_persistence_');
      final instanceName = 'persistence_${tempDir!.path.hashCode}';
      final pdf = File('${tempDir!.path}/downloaded.pdf');
      await pdf.writeAsBytes([37, 80, 68, 70]);
      final now = DateTime.utc(2026, 11, 6);

      isar = await openAppIsar(name: instanceName, directory: tempDir!.path);
      isar!.write((db) {
        db.playlists.put(
          Playlist()
            ..id = db.playlists.autoIncrement()
            ..playlistId = 'persisted-list'
            ..nome = 'Lista offline'
            ..pdfIds = ['downloaded']
            ..createdAt = now,
        );
        db.offlinePdfIndexs.put(
          OfflinePdfIndex()
            ..id = db.offlinePdfIndexs.autoIncrement()
            ..pdfId = 'downloaded'
            ..storagePath = pdf.path
            ..category = 'ColAdultos'
            ..fileSize = 4
            ..downloadedAt = now
            ..isPersistent = true,
        );
      });
      isar!.close();

      isar = await openAppIsar(name: instanceName, directory: tempDir!.path);
      final playlist = isar!.playlists.where().findAll().single;
      final offline = isar!.offlinePdfIndexs.where().findAll().single;
      expect(playlist.playlistId, 'persisted-list');
      expect(playlist.nome, 'Lista offline');
      expect(playlist.pdfIds, ['downloaded']);
      expect(offline.pdfId, 'downloaded');
      expect(offline.storagePath, pdf.path);
      expect(offline.isPersistent, isTrue);
      expect(await File(offline.storagePath).readAsBytes(), [37, 80, 68, 70]);
    },
  );

  test(
    'upgrade from release 1.0.1 schemas and core 1.3.7 preserves saved data',
    () async {
      tempDir = await Directory.systemTemp.createTemp('isar_legacy_upgrade_');
      // Dados sintéticos gravados com o core 1.3.7 e schemas da tag v1.0.1+3.
      final fixture = ZipDecoder()
          .decodeBytes(
            await File('test/fixtures/database/isar_plus_1_3_7.zip')
                .readAsBytes(),
          )
          .files
          .single;
      expect(fixture.name, '$kAppIsarName.isar');
      await File('${tempDir!.path}/$kAppIsarName.isar')
          .writeAsBytes(fixture.content);

      isar = await openAppIsar(directory: tempDir!.path);

      final playlist = isar!.playlists.where().findAll().single;
      final offline = isar!.offlinePdfIndexs.where().findAll().single;
      expect(playlist.playlistId, 'legacy-list');
      expect(playlist.nome, 'Lista do release 1.0.1');
      expect(playlist.pdfIds, ['legacy-pdf']);
      expect(playlist.salva, isTrue);
      expect(playlist.ownerSub, isNull);
      expect(offline.pdfId, 'legacy-pdf');
      expect(offline.storagePath, 'downloaded.pdf');
      expect(offline.fileSize, 4);
      expect(offline.isPersistent, isTrue);

      isar!.close();
      isar = await openAppIsar(directory: tempDir!.path);
      expect(
        isar!.playlists.where().findAll().single.playlistId,
        'legacy-list',
      );
      expect(
        isar!.offlinePdfIndexs.where().findAll().single.pdfId,
        'legacy-pdf',
      );
    },
  );
}
