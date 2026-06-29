import 'dart:io';

import 'package:coldigui/core/database/collections/carousel_entry.dart';
import 'package:coldigui/features/carousel/data/datasources/carousel_local_datasource.dart';
import 'package:coldigui/features/carousel/data/repositories/carousel_repository_impl.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/domain/usecases/add_louvor_to_carousel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late CarouselRepositoryImpl repository;
  late CarouselLocalDatasource datasource;


  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('carousel_repo_');
    isar = Isar.open(schemas: [CarouselEntrySchema],
      directory: tempDir.path,
    );
    datasource = CarouselLocalDatasource(isar);
    repository = CarouselRepositoryImpl(datasource);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('add append e duplicata ignorada', () async {
    await repository.add('pdf-a');
    await repository.add('pdf-b');
    await repository.add('pdf-a');

    final ids = await repository.getOrderedPdfIds();
    expect(ids, ['pdf-a', 'pdf-b']);
  });

  test('remove compacta sortOrder', () async {
    await repository.add('pdf-a');
    await repository.add('pdf-b');
    await repository.add('pdf-c');

    await repository.remove('pdf-b');

    final entries = await datasource.findAllOrdered();
    expect(entries.map((e) => e.pdfId), ['pdf-a', 'pdf-c']);
    expect(entries.map((e) => e.sortOrder), [0, 1]);
  });

  test('reorder reescreve ordem', () async {
    await repository.add('pdf-a');
    await repository.add('pdf-b');
    await repository.add('pdf-c');

    await repository.reorder(['pdf-c', 'pdf-a', 'pdf-b']);

    expect(await repository.getOrderedPdfIds(), ['pdf-c', 'pdf-a', 'pdf-b']);
  });

  test('reorder rejeita conjunto diferente', () async {
    await repository.add('pdf-a');
    await repository.add('pdf-b');

    expect(
      () => repository.reorder(['pdf-a']),
      throwsArgumentError,
    );
  });

  test('replaceAll substitui seleção', () async {
    await repository.add('pdf-a');
    await repository.replaceAll(['pdf-x', 'pdf-y']);

    expect(await repository.getOrderedPdfIds(), ['pdf-x', 'pdf-y']);
  });

  test('clear remove tudo', () async {
    await repository.add('pdf-a');
    await repository.add('pdf-b');

    await repository.clear();

    expect(await repository.getOrderedPdfIds(), isEmpty);
    await repository.clear();
    expect(await repository.getOrderedPdfIds(), isEmpty);
  });

  test('getOrderedItems usa label map e fallback', () async {
    await repository.add('pdf-a');
    await repository.add('missing');

    final items = await repository.getOrderedItems(
      pdfIdToMetadata: {
        'pdf-a': const CarouselItemMetadata(
          numero: '001',
          nome: 'Teste',
          categoria: 'Partitura',
          classificacao: 'ColAdultos',
        ),
      },
    );

    expect(items[0].label, '001 — Teste');
    expect(items[1].nome, 'missing');
  });

  test('AddLouvorToCarousel retorna false em duplicata', () async {
    final useCase = AddLouvorToCarousel(repository);

    expect(await useCase(pdfId: 'pdf-a'), isTrue);
    expect(await useCase(pdfId: 'pdf-a'), isFalse);
    expect(await repository.getOrderedPdfIds(), ['pdf-a']);
  });
}
