import 'dart:io';

import 'package:coldigui/core/database/collections/carousel_entry.dart';
import 'package:coldigui/features/carousel/data/datasources/carousel_local_datasource.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/data/repositories/carousel_repository_impl.dart';
import 'package:coldigui/features/leaflet/domain/usecases/generate_leaflet_from_selection.dart';
import 'package:coldigui/features/playlists/domain/exceptions/empty_carousel_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late CarouselRepositoryImpl carouselRepository;
  late GenerateLeafletFromSelection useCase;


  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('leaflet_uc08_');
    isar = Isar.open(schemas: [CarouselEntrySchema],
      directory: tempDir.path,
    );
    carouselRepository = CarouselRepositoryImpl(CarouselLocalDatasource(isar));
    useCase = GenerateLeafletFromSelection(carouselRepository);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('retorna LeafletDocument com índices e campos ordenados', () async {
    await carouselRepository.add('pdf-a');
    await carouselRepository.add('pdf-b');
    final generatedAt = DateTime(2026, 6, 11);

    final doc = await useCase(
      pdfIdToMetadata: {
        'pdf-a': const CarouselItemMetadata(
          numero: '001',
          nome: 'Louvor A',
          categoria: 'Partitura',
          classificacao: 'ColAdultos',
        ),
        'pdf-b': const CarouselItemMetadata(
          numero: '002',
          nome: 'Louvor B',
          categoria: 'Partitura',
          classificacao: 'ColAdultos',
        ),
      },
      generatedAt: generatedAt,
    );

    expect(doc.generatedAt, generatedAt);
    expect(doc.entries.length, 2);
    expect(doc.entries[0].index, 1);
    expect(doc.entries[0].numero, '001');
    expect(doc.entries[0].nome, 'Louvor A');
    expect(doc.entries[1].index, 2);
    expect(doc.entries[1].numero, '002');
    expect(doc.entries[1].nome, 'Louvor B');
  });

  test('lança EmptyCarouselException quando seleção vazia', () async {
    expect(
      () => useCase(),
      throwsA(isA<EmptyCarouselException>()),
    );
  });
}
