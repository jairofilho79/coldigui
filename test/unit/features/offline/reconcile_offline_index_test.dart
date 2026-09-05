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

/// Desembrulha um [ReconcileOutcome] esperado como concluído.
ReconcileDone _done(ReconcileOutcome outcome) {
  expect(outcome, isA<ReconcileDone>());
  return outcome as ReconcileDone;
}

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

    final result = _done(await useCase());

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

    final result = _done(
      await useCase(materialPackage: package, materialCategory: 'Partitura'),
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

    final result = _done(await useCase());

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

    final result = _done(await useCase());

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

    final first = _done(await useCase());
    final second = _done(await useCase());

    expect(first.removedFromIndex, 0);
    expect(second.removedFromIndex, 0);
    expect(second.orphanFiles, 0);
  });

  test(
    'reconcile completo com índice indisponível é pulado sem apagar nada',
    () async {
      final orphanPath = await store.writeAtomic(
        pdfBytes,
        'ColAdultos/001.pdf',
      );

      final outcome = await useCase(isIndexAvailable: false);

      expect(outcome, isA<ReconcileSkipped>());
      expect(
        (outcome as ReconcileSkipped).reason,
        ReconcileSkipReason.indexUnavailable,
      );
      expect(await File(orphanPath).exists(), isTrue);
    },
  );

  test(
    'reconcile completo com índice vazio e arquivos no disco é pulado',
    () async {
      final aPath = await store.writeAtomic(pdfBytes, 'ColAdultos/001.pdf');
      final bPath = await store.writeAtomic(pdfBytes, 'ColAdultos/002.pdf');

      final outcome = await useCase();

      expect(outcome, isA<ReconcileSkipped>());
      expect(
        (outcome as ReconcileSkipped).reason,
        ReconcileSkipReason.emptyIndexWithFiles,
      );
      expect(await File(aPath).exists(), isTrue);
      expect(await File(bPath).exists(), isTrue);
    },
  );

  test(
    'reconcile completo com 1 linha e muitos arquivos é pulado (indexTooSmall)',
    () async {
      // Índice com uma entrada só (a linha que sobrou de um Isar truncado) e
      // um disco cheio: seguir apagaria tudo como "órfão".
      final indexed = await repository.upsert(
        pdfId: pdfId,
        bytes: pdfBytes,
        category: 'ColAdultos',
      );
      final onDisk = <String>[indexed.absolutePath];
      for (var i = 2; i <= 8; i++) {
        onDisk.add(
          await store.writeAtomic(
            pdfBytes,
            'ColAdultos/${i.toString().padLeft(3, '0')}.pdf',
          ),
        );
      }

      final outcome = await useCase();

      expect(outcome, isA<ReconcileSkipped>());
      expect(
        (outcome as ReconcileSkipped).reason,
        ReconcileSkipReason.indexTooSmall,
      );
      for (final path in onDisk) {
        expect(await File(path).exists(), isTrue);
      }
      expect(await repository.lookup(pdfId), isNotNull);
    },
  );

  test(
    'reconcile escopado não é pulado por índice menor que o disco',
    () async {
      final indexed = await repository.upsert(
        pdfId: pdfId,
        bytes: pdfBytes,
        category: 'ColAdultos',
      );
      final orphan = await store.writeAtomic(pdfBytes, 'ColAdultos/002.pdf');
      for (var i = 3; i <= 8; i++) {
        await store.writeAtomic(
          pdfBytes,
          'ColAdultos/${i.toString().padLeft(3, '0')}.pdf',
        );
      }

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

      final outcome = await useCase(
        materialPackage: package,
        materialCategory: 'Partitura',
      );

      expect(outcome, isA<ReconcileDone>());
      expect(await File(indexed.absolutePath).exists(), isTrue);
      expect(await File(orphan).exists(), isFalse);
    },
  );

  test('reconcile completo com índice vazio e disco vazio conclui', () async {
    final outcome = await useCase();

    expect(outcome, isA<ReconcileDone>());
    expect((outcome as ReconcileDone).orphanFiles, 0);
  });

  test(
    'reconcile escopado preserva PDF indexado fora do escopo na mesma pasta',
    () async {
      final outOfScopeId = encodePdfId('ColAdultos/002.pdf');
      final inScope = await repository.upsert(
        pdfId: pdfId,
        bytes: pdfBytes,
        category: 'ColAdultos',
      );
      final outOfScope = await repository.upsert(
        pdfId: outOfScopeId,
        bytes: pdfBytes,
        category: 'ColAdultos',
      );

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

      final outcome = _done(
        await useCase(materialPackage: package, materialCategory: 'Partitura'),
      );

      expect(outcome.orphanFiles, 0);
      expect(await File(inScope.absolutePath).exists(), isTrue);
      expect(await File(outOfScope.absolutePath).exists(), isTrue);
      expect(await repository.lookup(outOfScopeId), isNotNull);
    },
  );

  test(
    'reconcile escopado com índice vazio só apaga órfãos do escopo',
    () async {
      final scopedOrphan = await store.writeAtomic(
        pdfBytes,
        'Partitura/001.pdf',
      );
      final outOfScope = await store.writeAtomic(
        pdfBytes,
        'ColAdultos/001.pdf',
      );

      final package = OfflineMaterialPackage(
        parts: [
          OfflinePackagePart(
            filename: 'Partitura-1.zip',
            size: 100,
            url: '/packages/Partitura-1.zip',
            pdfs: [encodePdfId('Partitura/999.pdf')],
          ),
        ],
        totalSize: 100,
        totalParts: 1,
      );

      final outcome = _done(
        await useCase(
          materialPackage: package,
          materialCategory: 'Partitura',
          isIndexAvailable: false,
        ),
      );

      expect(outcome.orphanFiles, 1);
      expect(await File(scopedOrphan).exists(), isFalse);
      expect(await File(outOfScope).exists(), isTrue);
    },
  );
}
