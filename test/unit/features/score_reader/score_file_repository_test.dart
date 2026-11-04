import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/score_reader/data/datasources/score_byte_store.dart';
import 'package:coldigui/features/score_reader/data/datasources/score_byte_store_native.dart';
import 'package:coldigui/features/score_reader/data/repositories/score_file_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late ScoreByteStoreNative store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('coldigui-score-test-');
    store = ScoreByteStoreNative(documentsDirectory: () async => directory);
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  Dio responding(int status, List<int> bytes) {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<List<int>>(
            requestOptions: options,
            statusCode: status,
            data: bytes,
          ),
        ),
      ),
    );
    addTearDown(dio.close);
    return dio;
  }

  test('keys differing by separators never overwrite each other', () async {
    const first = 'assets/praises/a_b/file.mscz';
    const second = 'assets/praises/a/b_file.mscz';
    expect(
      scoreByteStoreFileName(first),
      isNot(scoreByteStoreFileName(second)),
    );
    await store.write(first, Uint8List.fromList([1, 2]));
    await store.write(second, Uint8List.fromList([3, 4]));
    expect(await store.read(first), [1, 2]);
    expect(await store.read(second), [3, 4]);
  });

  test(
    'long R2 keys survive a new native store without filename errors',
    () async {
      final key = 'assets/praises/${List.filled(220, 'a').join()}/voz.musicxml';
      await store.write(key, Uint8List.fromList([1, 2, 3]));
      final reopened = ScoreByteStoreNative(
        documentsDirectory: () async => directory,
      );
      expect(await reopened.contains(key), isTrue);
      expect(await reopened.read(key), [1, 2, 3]);
      expect(scoreByteStoreFileName(key).length, lessThanOrEqualTo(255));
    },
  );

  test(
    'download survives a new store and repository without network',
    () async {
      const key = 'assets/praises/001/score.mscz';
      final repository = ScoreFileRepository(
        store,
        responding(200, [80, 75, 3, 4]),
        apiBase: 'https://example.test/api/coldigom',
      );
      expect(await repository.fetch(key), [80, 75, 3, 4]);

      final offline = Dio();
      offline.interceptors.add(
        InterceptorsWrapper(
          onRequest: (_, _) => fail('cached scores must not need a network'),
        ),
      );
      addTearDown(offline.close);
      final reopened = ScoreFileRepository(
        ScoreByteStoreNative(documentsDirectory: () async => directory),
        offline,
        apiBase: 'https://example.test/api/coldigom',
      );
      expect(await reopened.readLocal(key), [80, 75, 3, 4]);
      expect(await reopened.hasLocal(key), isTrue);
      expect((await reopened.localPresence())(key), isTrue);
    },
  );

  test('404 is absent and is not stored', () async {
    final repository = ScoreFileRepository(
      store,
      responding(404, []),
      apiBase: 'https://example.test',
    );
    expect(await repository.fetch('missing.mscz'), isNull);
    expect(await repository.hasLocal('missing.mscz'), isFalse);
  });

  test('an empty successful response is an explicit fetch failure', () async {
    final repository = ScoreFileRepository(
      store,
      responding(200, []),
      apiBase: 'https://example.test',
    );
    await expectLater(
      repository.fetch('empty.mscz'),
      throwsA(isA<ScoreFetchFailedException>()),
    );
    expect(await repository.hasLocal('empty.mscz'), isFalse);
  });

  test('an empty key is rejected rather than treated as a missing score', () {
    final repository = ScoreFileRepository(
      store,
      responding(200, [1]),
      apiBase: 'https://example.test',
    );
    expect(repository.fetch('  '), throwsArgumentError);
  });
}
