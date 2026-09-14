import 'dart:io';

import 'package:coldigui/core/database/collections/chord_content_cache.dart';
import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/core/database/collections/gesture_document_cache.dart';
import 'package:coldigui/core/database/collections/offline_audio_index.dart';
import 'package:coldigui/core/database/collections/offline_pdf_index.dart';
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/chords/data/providers/chord_providers.dart';
import 'package:coldigui/features/gestures/data/providers/gesture_providers.dart';
import 'package:coldigui/features/offline/data/providers/offline_audio_providers.dart';
import 'package:coldigui/features/offline/data/providers/offline_repository_providers.dart';
import 'package:coldigui/features/offline/presentation/providers/material_availability_map_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_coldigom_stats_provider.dart';
import 'package:coldigui/features/pdf_opening/domain/entities/pdf_offline_availability.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('availability_');
    isar = Isar.open(
      schemas: [
        OfflinePdfIndexSchema,
        OfflineAudioIndexSchema,
        ChordContentCacheSchema,
        GestureDocumentCacheSchema,
        ColdigomPraiseCacheSchema,
      ],
      directory: tempDir.path,
      name: 'availability_${DateTime.now().microsecondsSinceEpoch}',
    );
    container = ProviderContainer(
      overrides: [isarInitializerProvider.overrideWith((ref) async => isar)],
    );
    addTearDown(container.dispose);
    await container.read(isarInitializerProvider.future);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test(
    'une PDF (LRU/persistente), áudio, cifra e gestos com conteúdo',
    () async {
      final pdfLru = encodePdfId('assets/praises/p/a.pdf');
      final pdfPersist = encodePdfId('assets/praises/p/b.pdf');
      final audio = encodePdfId('assets/praises/p/c.mp3');
      const chordKey = 'assets/praises/p/d.chord';
      const chordEmptyKey = 'assets/praises/p/e.chord';
      const gestKey = 'assets/praises/p/f.gestures';

      final pdfLocal = container.read(offlinePdfLocalDatasourceProvider);
      await pdfLocal.put(_pdf(pdfLru, persistent: false));
      await pdfLocal.put(_pdf(pdfPersist, persistent: true));
      await container
          .read(offlineAudioLocalDatasourceProvider)
          .put(
            OfflineAudioIndex()
              ..audioId = audio
              ..r2Key = 'assets/praises/p/c.mp3'
              ..storageKey = '/x'
              ..fileSize = 1
              ..downloadedAt = DateTime(2026),
          );
      container
          .read(chordContentLocalDatasourceProvider)
          .write(chordKey, '{t: x}');
      container
          .read(chordContentLocalDatasourceProvider)
          .write(chordEmptyKey, '');
      container
          .read(gestureContentLocalDatasourceProvider)
          .write(gestKey, '{}');
      container.read(chordGestureCacheRevisionProvider.notifier).bump();

      final map = container.read(materialAvailabilityMapProvider);

      expect(map[pdfLru], PdfOfflineAvailability.cachedLru);
      expect(map[pdfPersist], PdfOfflineAvailability.persistentOffline);
      expect(map[audio], PdfOfflineAvailability.persistentOffline);
      expect(
        map[encodePdfId(chordKey)],
        PdfOfflineAvailability.persistentOffline,
      );
      expect(map.containsKey(encodePdfId(chordEmptyKey)), isFalse);
      expect(
        map[encodePdfId(gestKey)],
        PdfOfflineAvailability.persistentOffline,
      );
    },
  );

  test('re-deriva quando a revisão de áudio sobe', () async {
    final audio = encodePdfId('assets/praises/p/c.mp3');
    expect(
      container.read(materialAvailabilityMapProvider).containsKey(audio),
      isFalse,
    );

    await container
        .read(offlineAudioLocalDatasourceProvider)
        .put(
          OfflineAudioIndex()
            ..audioId = audio
            ..r2Key = 'x'
            ..storageKey = '/x'
            ..fileSize = 1
            ..downloadedAt = DateTime(2026),
        );

    expect(
      container.read(materialAvailabilityMapProvider)[audio],
      PdfOfflineAvailability.persistentOffline,
    );
  });
}

OfflinePdfIndex _pdf(String id, {required bool persistent}) => OfflinePdfIndex()
  ..pdfId = id
  ..storagePath = '/x/$id'
  ..category = 'x'
  ..fileSize = 1
  ..downloadedAt = DateTime(2026)
  ..isPersistent = persistent;
