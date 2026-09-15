import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/database/collections/offline_audio_index.dart';
import 'package:coldigui/features/offline/data/datasources/audio_storage_native.dart';
import 'package:coldigui/features/offline/data/datasources/offline_audio_local_datasource.dart';
import 'package:coldigui/features/offline/data/repositories/offline_audio_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late OfflineAudioRepositoryImpl repository;
  late AudioStorageNative store;
  late int indexChangedCount;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('audio_repo_');
    isar = Isar.open(
      schemas: [OfflineAudioIndexSchema],
      directory: tempDir.path,
      name: 'audio_repo_${DateTime.now().microsecondsSinceEpoch}',
    );
    store = AudioStorageNative(
      getApplicationDocumentsDirectory: () async =>
          Directory('${tempDir.path}/docs'),
    );
    indexChangedCount = 0;
    repository = OfflineAudioRepositoryImpl(
      store: store,
      local: OfflineAudioLocalDatasource(
        isar,
        onIndexChanged: () => indexChangedCount++,
      ),
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  final bytes = Uint8List.fromList(List.filled(16, 7));

  test('upsert grava bytes e índice; lookup devolve a fonte local', () async {
    final entry = await repository.upsert(
      audioId: 'a1',
      r2Key: 'assets/praises/p1/m1.mp3',
      bytes: bytes,
    );

    expect(entry.fileSize, 16);
    expect(entry.storageKey, endsWith('plpcg_audio/assets/praises/p1/m1.mp3'));
    final local = (await repository.lookup('a1'))!;
    expect(local.storageKey, entry.storageKey);
    expect(await store.readBytes(local.storageKey), bytes);
    expect(await repository.totalBytes(), 16);
    expect(
      (await repository.listAll()).single.r2Key,
      'assets/praises/p1/m1.mp3',
    );
  });

  test(
    'lookup é null sem índice ou sem ficheiro; lookupBatch filtra os dois',
    () async {
      await repository.upsert(audioId: 'a1', r2Key: 'p1/m1.mp3', bytes: bytes);
      await repository.upsert(audioId: 'a2', r2Key: 'p1/m2.mp3', bytes: bytes);
      final a2 = (await repository.lookup('a2'))!;
      await store.delete(a2.storageKey);

      expect(await repository.lookup('zz'), isNull);
      expect(await repository.lookup('a2'), isNull);
      expect(await repository.lookupBatch({'a1', 'a2', 'zz'}), {'a1'});
    },
  );

  test(
    'lookup purga a entrada órfã (bytes evictados) do índice e bumpa a revisão',
    () async {
      final entry = await repository.upsert(
        audioId: 'a1',
        r2Key: 'p1/m1.mp3',
        bytes: bytes,
      );
      await store.delete(entry.storageKey);
      final countBeforeLookup = indexChangedCount;

      expect(await repository.lookup('a1'), isNull);

      expect(indexChangedCount, greaterThan(countBeforeLookup));
      expect((await repository.listAll()), isEmpty);
      // Idempotente: sem índice, não há mais nada para purgar/bumpar.
      final countAfterFirstPurge = indexChangedCount;
      expect(await repository.lookup('a1'), isNull);
      expect(indexChangedCount, countAfterFirstPurge);
    },
  );

  test('lookupBatch purga apenas as entradas com ficheiro ausente', () async {
    await repository.upsert(audioId: 'a1', r2Key: 'p1/m1.mp3', bytes: bytes);
    final a2 = await repository.upsert(
      audioId: 'a2',
      r2Key: 'p1/m2.mp3',
      bytes: bytes,
    );
    await store.delete(a2.storageKey);
    final countBeforeBatch = indexChangedCount;

    expect(await repository.lookupBatch({'a1', 'a2'}), {'a1'});

    expect(indexChangedCount, greaterThan(countBeforeBatch));
    expect((await repository.listAll()).map((e) => e.audioId), ['a1']);
  });

  test('remove apaga ficheiro e índice; removeAll limpa tudo', () async {
    await repository.upsert(audioId: 'a1', r2Key: 'p1/m1.mp3', bytes: bytes);
    await repository.upsert(audioId: 'a2', r2Key: 'p1/m2.mp3', bytes: bytes);
    final a1 = (await repository.lookup('a1'))!;

    await repository.remove('a1');
    await repository.remove('a1');
    expect(await store.exists(a1.storageKey), isFalse);
    expect((await repository.listAll()).map((e) => e.audioId), ['a2']);

    await repository.removeAll();
    expect(await repository.listAll(), isEmpty);
    expect(await store.getTotalBytes(), 0);
  });
}
