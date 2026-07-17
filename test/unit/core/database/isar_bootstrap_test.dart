import 'dart:io';

import 'package:coldigui/core/database/collections/audio_flag.dart';
import 'package:coldigui/core/database/collections/carousel_entry.dart';
import 'package:coldigui/core/database/collections/louvor_cache.dart';
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
    expect(kAppIsarSchemas.length, 5);

    isar!.write((isar) {
      expect(isar.louvorCaches, isNotNull);
      expect(isar.carouselEntrys, isNotNull);
      expect(isar.playlists, isNotNull);
      expect(isar.offlinePdfIndexs, isNotNull);
      expect(isar.audioFlags, isNotNull);
    });
  });
}
