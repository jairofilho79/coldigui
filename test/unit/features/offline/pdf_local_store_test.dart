import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/constants/offline_config.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory docsDir;
  late PdfLocalStore store;

  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('pdf_local_store_');
    store = PdfLocalStore(
      getApplicationDocumentsDirectory: () async => docsDir,
    );
  });

  tearDown(() async {
    if (docsDir.existsSync()) {
      await docsDir.delete(recursive: true);
    }
  });

  test('rootDirectory resolve para docs/plpcg_pdfs/', () async {
    final root = await store.rootDirectory;
    expect(
      root.path,
      '${docsDir.path}/${OfflineConfig.pdfStorageSubdir}',
    );
    expect(await root.exists(), isTrue);
  });

  test('writeAtomic cria arquivo com bytes corretos', () async {
    final bytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]); // %PDF
    const relPath = 'ColAdultos/001.pdf';

    final absolutePath = await store.writeAtomic(bytes, relPath);

    expect(absolutePath, endsWith('ColAdultos/001.pdf'));
    final file = File(absolutePath);
    expect(await file.exists(), isTrue);
    expect(await file.readAsBytes(), bytes);
    expect(await File('$absolutePath.tmp').exists(), isFalse);
  });

  test('writeAtomic cria subpastas quando necessário', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    const relPath = 'ColAdultos/Cifra nível I/002.pdf';

    final absolutePath = await store.writeAtomic(bytes, relPath);
    expect(await File(absolutePath).exists(), isTrue);
  });

  test('falha no rename não corrompe destino pré-existente', () async {
    const relPath = 'ColAdultos/001.pdf';
    final originalBytes = Uint8List.fromList([10, 20, 30]);
    final newBytes = Uint8List.fromList([99, 99, 99]);

    final absolutePath = await store.writeAtomic(originalBytes, relPath);

    // Diretório com o mesmo nome impede rename no Unix.
    await File(absolutePath).delete();
    await Directory(absolutePath).create(recursive: true);

    expect(
      () => store.writeAtomic(newBytes, relPath),
      throwsA(isA<FileSystemException>()),
    );

    expect(await Directory(absolutePath).exists(), isTrue);
    expect(await File('$absolutePath.tmp').exists(), isFalse);
  });

  test('exists e delete comportam-se como esperado', () async {
    final bytes = Uint8List.fromList([1]);
    const relPath = 'ColAdultos/003.pdf';

    final path = await store.writeAtomic(bytes, relPath);
    expect(await store.exists(path), isTrue);

    await store.delete(path);
    expect(await store.exists(path), isFalse);

    // Idempotente.
    await store.delete(path);
  });

  test('listOrphans retorna PDF no disco sem entrada indexada', () async {
    final indexedBytes = Uint8List.fromList([1]);
    final orphanBytes = Uint8List.fromList([2]);

    final indexedPath =
        await store.writeAtomic(indexedBytes, 'ColAdultos/indexed.pdf');
    final orphanPath =
        await store.writeAtomic(orphanBytes, 'ColAdultos/orphan.pdf');

    final orphans = await store.listOrphans({indexedPath});

    expect(orphans, contains(orphanPath));
    expect(orphans, isNot(contains(indexedPath)));
  });

  test('deleteTree remove árvore e recria root vazio', () async {
    await store.writeAtomic(Uint8List.fromList([1]), 'ColAdultos/a.pdf');
    final rootBefore = await store.rootDirectory;
    expect(await rootBefore.exists(), isTrue);

    await store.deleteTree();

    final rootAfter = await store.rootDirectory;
    expect(await rootAfter.exists(), isTrue);
    expect(await rootAfter.list().length, 0);
  });
}
