import 'dart:io';

import 'package:coldigui/core/database/collections/offline_audio_index.dart';
import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/features/offline/data/datasources/offline_audio_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

OfflineAudioIndex _row(String audioId, {int size = 10}) => OfflineAudioIndex()
  ..audioId = audioId
  ..r2Key = 'assets/praises/p1/$audioId.mp3'
  ..storageKey = '/docs/plpcg_audio/p1/$audioId.mp3'
  ..fileSize = size
  ..downloadedAt = DateTime.utc(2026, 9, 14);

void main() {
  late Directory tempDir;
  late Isar isar;
  late OfflineAudioLocalDatasource datasource;
  var changes = 0;

  setUp(() async {
    changes = 0;
    tempDir = await Directory.systemTemp.createTemp('offline_audio_');
    isar = Isar.open(
      schemas: [OfflineAudioIndexSchema],
      directory: tempDir.path,
      name: 'offline_audio_${DateTime.now().microsecondsSinceEpoch}',
    );
    datasource = OfflineAudioLocalDatasource(
      isar,
      onIndexChanged: () => changes++,
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('put faz upsert por audioId e avisa a revisão', () async {
    await datasource.put(_row('a1', size: 5));
    await datasource.put(_row('a1', size: 7));

    expect(datasource.findAllSync(), hasLength(1));
    expect(datasource.findByAudioIdSync('a1')!.fileSize, 7);
    expect(datasource.sumFileSizes(), 7);
    expect(changes, 2);
  });

  test(
    'findByAudioIds devolve só os presentes; delete e clear avisam',
    () async {
      await datasource.put(_row('a1'));
      await datasource.put(_row('a2'));

      expect(datasource.findByAudioIds({'a1', 'zz'}).map((e) => e.audioId), [
        'a1',
      ]);

      await datasource.deleteByAudioId('a1');
      await datasource.deleteByAudioId('a1');
      expect(datasource.findAllSync().map((e) => e.audioId), ['a2']);

      await datasource.clearAll();
      expect(datasource.findAllSync(), isEmpty);
      expect(changes, 5);
    },
  );

  test('sem Isar: leituras vazias, escritas lançam', () async {
    const degraded = OfflineAudioLocalDatasource.unavailable();

    expect(degraded.findAllSync(), isEmpty);
    expect(degraded.findByAudioIdSync('a1'), isNull);
    expect(degraded.sumFileSizes(), 0);
    await expectLater(
      degraded.put(_row('a1')),
      throwsA(isA<StorageUnavailableException>()),
    );
    await expectLater(
      degraded.clearAll(),
      throwsA(isA<StorageUnavailableException>()),
    );
  });
}
