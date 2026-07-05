import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/entities/offline_manifest.dart';
import 'package:coldigui/features/offline/domain/usecases/reconcile_offline_index.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

import 'offline_test_helpers.dart';

void main() {
  late Directory tempDir;
  late Directory docsDir;
  late Isar isar;
  late PdfLocalStore store;
  late OfflinePdfRepositoryImpl repository;
  late ReconcileOfflineIndex useCase;

  final pdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
  late String pdfId;

  setUpAll(() async {
    pdfId = encodePdfId('ColAdultos/001.pdf');
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reconcile_');
    docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);

    isar = openOfflineTestIsar(tempDir);
    store = PdfLocalStore(
      getApplicationDocumentsDirectory: () async => docsDir,
    );
    repository = OfflinePdfRepositoryImpl(
      store: pdfStoragePortFor(store),
      local: OfflinePdfLocalDatasource(isar),
    );
    useCase = ReconcileOfflineIndex(repository, pdfStoragePortFor(store));
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('remove entrada índice com conteúdo HTML inválido', () async {
    final entry = await repository.upsert(
      pdfId: pdfId,
      bytes: Uint8List.fromList('<html>'.codeUnits),
      category: 'ColAdultos',
    );
    expect(await File(entry.absolutePath).exists(), isTrue);

    final result = await useCase();

    expect(result.removedFromIndex, 1);
    expect(await repository.lookup(pdfId), isNull);
  });

  test('remove entrada índice sem arquivo no disco', () async {
    final entry = await repository.upsert(
      pdfId: pdfId,
      bytes: pdfBytes,
      category: 'ColAdultos',
    );
    await File(entry.absolutePath).delete();

    final package = OfflineMaterialPackage(
      parts: [
        OfflinePackagePart(
          filename: 'Partitura-1.zip',
          size: 100,
          url: '/packages/Partitura-1.zip',
          pdfs: [pdfId],
        ),
      ],
      totalSize: 100,
      totalParts: 1,
    );

    final result = await useCase(
      materialPackage: package,
      materialCategory: 'Partitura',
    );

    expect(result.removedFromIndex, 1);
    expect(await repository.lookup(pdfId), isNull);
  });

  test('preserva entrada com arquivo válido', () async {
    await repository.upsert(
      pdfId: pdfId,
      bytes: pdfBytes,
      category: 'ColAdultos',
    );

    final result = await useCase();

    expect(result.removedFromIndex, 0);
    expect(await repository.lookup(pdfId), isNotNull);
  });

  test('reconcile global remove arquivo órfão no disco', () async {
    await repository.upsert(
      pdfId: pdfId,
      bytes: pdfBytes,
      category: 'ColAdultos',
    );

    final orphanBytes = Uint8List.fromList([9, 9, 9]);
    final orphanPath = await store.writeAtomic(
      orphanBytes,
      'ColAdultos/orphan-only.pdf',
    );

    final result = await useCase();

    expect(result.removedFromIndex, 0);
    expect(result.orphanFiles, 1);
    expect(await File(orphanPath).exists(), isFalse);
    expect(await repository.lookup(pdfId), isNotNull);
  });

  test('reconcile global é idempotente', () async {
    await repository.upsert(
      pdfId: pdfId,
      bytes: pdfBytes,
      category: 'ColAdultos',
    );

    final first = await useCase();
    final second = await useCase();

    expect(first.removedFromIndex, 0);
    expect(second.removedFromIndex, 0);
    expect(second.orphanFiles, 0);
  });
}
