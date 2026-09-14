import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/constants/offline_config.dart';
import 'package:coldigui/features/offline/data/datasources/audio_storage_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory docsDir;
  late AudioStorageNative store;

  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('audio_storage_');
    store = AudioStorageNative(
      getApplicationDocumentsDirectory: () async => docsDir,
    );
  });

  tearDown(() async {
    if (docsDir.existsSync()) await docsDir.delete(recursive: true);
  });

  test('writeAtomic grava em docs/plpcg_audio/<relPath> sem deixar .tmp', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);

    final key = await store.writeAtomic(bytes, 'assets/praises/p1/m1.mp3');

    expect(
      key,
      '${docsDir.path}/${OfflineConfig.audioStorageSubdir}/assets/praises/p1/m1.mp3',
    );
    expect(await File(key).readAsBytes(), bytes);
    expect(await File('$key.tmp').exists(), isFalse);
    expect(await store.exists(key), isTrue);
    expect(await store.readBytes(key), bytes);
    expect(await store.getTotalBytes(), 4);
  });

  test('delete é idempotente e readBytes devolve null para ausente', () async {
    final key = await store.writeAtomic(Uint8List.fromList([9]), 'p1/m1.mp3');

    await store.delete(key);
    await store.delete(key);

    expect(await store.exists(key), isFalse);
    expect(await store.readBytes(key), isNull);
  });

  test('deleteTree apaga tudo e recria a raiz vazia', () async {
    await store.writeAtomic(Uint8List.fromList([1]), 'p1/a.mp3');
    await store.writeAtomic(Uint8List.fromList([1, 2]), 'p2/b.mp3');

    await store.deleteTree();

    expect(await store.getTotalBytes(), 0);
    expect(
      await Directory('${docsDir.path}/${OfflineConfig.audioStorageSubdir}')
          .exists(),
      isTrue,
    );
  });
}
