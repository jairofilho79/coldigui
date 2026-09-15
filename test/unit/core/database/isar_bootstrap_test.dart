import 'dart:io';

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
}
