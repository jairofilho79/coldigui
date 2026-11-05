@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:coldigui/features/score_reader/data/datasources/score_byte_store.dart';
import 'package:coldigui/features/score_reader/data/datasources/score_byte_store_web.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('score bytes survive a new Web store without a network', () async {
    final key = 'score-test/${DateTime.now().microsecondsSinceEpoch}/a.mscz';
    final original = ScoreByteStoreWeb();
    addTearDown(() => original.delete(key));
    await original.write(key, Uint8List.fromList([80, 75, 3, 4]));

    final reopened = ScoreByteStoreWeb();
    expect(await reopened.read(key), [80, 75, 3, 4]);
    expect(await reopened.contains(key), isTrue);
    expect(await reopened.fileNames(), contains(scoreByteStoreFileName(key)));
    await reopened.delete(key);
    expect(await original.contains(key), isFalse);
  });

  test('Web keys cannot alias each other after normalization', () async {
    final prefix = 'score-test/${DateTime.now().microsecondsSinceEpoch}';
    final first = '$prefix/a_b/file.mxl';
    final second = '$prefix/a/b_file.mxl';
    final store = ScoreByteStoreWeb();
    addTearDown(() async {
      await store.delete(first);
      await store.delete(second);
    });
    await store.write(first, Uint8List.fromList([1, 2]));
    await store.write(second, Uint8List.fromList([3, 4]));
    expect(await store.read(first), [1, 2]);
    expect(await store.read(second), [3, 4]);
  });
}
