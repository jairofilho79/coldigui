import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/catalog/domain/legacy_ids/legacy_id_store.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/legacy/offline_index_legacy_id_store.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

import 'offline_test_helpers.dart';

final _legadoA = encodePdfId('ColAdultos/001.pdf');
final _desconhecido = encodePdfId('ColAdultos/999.pdf');
final _coldigomA = encodePdfId('assets/praises/p1/m1.pdf');
final _coldigomB = encodePdfId('assets/praises/p2/m2.pdf');

LegacyIdResolution _resolution() => LegacyIdResolution(
  queried: {_legadoA, _desconhecido},
  resolved: {_legadoA: _coldigomA},
);

void main() {
  late Directory tempDir;
  late Isar isar;
  late OfflinePdfRepositoryImpl repository;
  var lockFree = true;
  var unlocks = 0;
  var indexChanges = 0;

  OfflineIndexLegacyIdStore store() => OfflineIndexLegacyIdStore(
    repository,
    tryLock: () => lockFree,
    unlock: () => unlocks++,
  );

  Future<String> seed(String pdfId, {bool isPersistent = true}) async {
    final entry = await repository.upsert(
      pdfId: pdfId,
      bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
      category: 'x',
      isPersistent: isPersistent,
    );
    return entry.absolutePath;
  }

  setUp(() async {
    lockFree = true;
    unlocks = 0;
    indexChanges = 0;
    tempDir = await Directory.systemTemp.createTemp('legacy_offline_');
    final docsDir = Directory('${tempDir.path}/docs')
      ..createSync(recursive: true);
    isar = openOfflineTestIsar(tempDir);
    repository = OfflinePdfRepositoryImpl(
      store: pdfStoragePortFor(
        PdfLocalStore(getApplicationDocumentsDirectory: () async => docsDir),
      ),
      local: OfflinePdfLocalDatasource(
        isar,
        onIndexChanged: () => indexChanges++,
      ),
    );
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('collect só devolve PDFs legados do índice', () async {
    await seed(_legadoA);
    await seed(_coldigomB);

    expect(await store().collectLegacyIds(), {_legadoA});
  });

  test(
    'resolvido: a linha passa ao id coldigom com o mesmo ficheiro',
    () async {
      final path = await seed(_legadoA);

      expect(await store().rewrite(_resolution()), 1);

      expect(await repository.findIndexEntry(_legadoA), isNull);
      final remapped = await repository.findIndexEntry(_coldigomA);
      expect(remapped?.absolutePath, path);
      expect(remapped?.isPersistent, isTrue);
      expect(unlocks, 1);
    },
  );

  test('colisão: já baixado com o id coldigom → a linha legada sai', () async {
    await seed(_legadoA);
    final coldigomPath = await seed(_coldigomA);

    await store().rewrite(_resolution());

    expect(await repository.findIndexEntry(_legadoA), isNull);
    expect(
      (await repository.findIndexEntry(_coldigomA))?.absolutePath,
      coldigomPath,
    );
  });

  test(
    'colisão: a linha que fica é persistente se qualquer das duas era',
    () async {
      await seed(_legadoA);
      await seed(_coldigomA, isPersistent: false);

      await store().rewrite(_resolution());

      final kept = await repository.findIndexEntry(_coldigomA);
      expect(kept?.isPersistent, isTrue);
    },
  );

  test('colisão: duas linhas só de cache continuam só de cache', () async {
    await seed(_legadoA, isPersistent: false);
    await seed(_coldigomA, isPersistent: false);

    await store().rewrite(_resolution());

    expect(await repository.findIndexEntry(_legadoA), isNull);
    expect((await repository.findIndexEntry(_coldigomA))?.isPersistent, false);
  });

  test(
    'desconhecido: a linha sai e o ficheiro fica para o reconcile',
    () async {
      final path = await seed(_desconhecido);

      expect(await store().rewrite(_resolution()), 1);

      expect(await repository.findIndexEntry(_desconhecido), isNull);
      expect(File(path).existsSync(), isTrue);
    },
  );

  test('resolvidos e desconhecidos: uma escrita só no índice', () async {
    await seed(_legadoA);
    await seed(_desconhecido);
    await seed(_coldigomB);
    indexChanges = 0;

    expect(await store().rewrite(_resolution()), 2);

    expect(indexChanges, 1);
    expect(await repository.findIndexEntry(_coldigomA), isNotNull);
    expect(await repository.findIndexEntry(_desconhecido), isNull);
    expect(await repository.findIndexEntry(_coldigomB), isNotNull);
  });

  test('manutenção ocupada: não mexe e não liberta o lock alheio', () async {
    await seed(_legadoA);
    lockFree = false;

    expect(await store().rewrite(_resolution()), 0);

    expect(await repository.findIndexEntry(_legadoA), isNotNull);
    expect(unlocks, 0);
  });
}
