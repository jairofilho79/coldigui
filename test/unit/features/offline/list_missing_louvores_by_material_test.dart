import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/catalog/data/datasources/catalog_local_datasource.dart';
import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/usecases/list_missing_louvores_by_material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

import 'offline_test_helpers.dart';

Louvor _louvor({
  required String pdfId,
  required String nome,
  required String numero,
  required String categoria,
}) {
  return Louvor(
    nome: nome,
    numero: numero,
    categoria: categoria,
    classificacao: 'ColAdultos',
    pdf: '$pdfId.pdf',
    pdfId: pdfId,
    groupId: pdfId,
    searchTitleNorm: nome.toLowerCase(),
    searchContentTokens: const [],
    searchCompactContent: '',
  );
}

void main() {
  late Isar isar;
  late OfflinePdfRepositoryImpl repository;
  late CatalogLocalDatasource catalogLocal;
  late ListMissingLouvoresByMaterial useCase;

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('missing_louvores_');
    final docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);

    isar = openOfflineCatalogTestIsar(tempDir);
    final pdfStore = PdfLocalStore(
      getApplicationDocumentsDirectory: () async => docsDir,
    );
    repository = OfflinePdfRepositoryImpl(
      store: pdfStoragePortFor(pdfStore),
      local: OfflinePdfLocalDatasource(isar),
    );
    catalogLocal = CatalogLocalDatasource(isar);
    useCase = ListMissingLouvoresByMaterial(catalogLocal, repository);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
  });

  test('retorna louvores sem PDF offline válido para o material', () async {
    final partituraPresent = _louvor(
      pdfId: encodePdfId('ColAdultos/a.pdf'),
      nome: 'Aleluia',
      numero: '001',
      categoria: 'Partitura',
    );
    final partituraMissing = _louvor(
      pdfId: encodePdfId('ColAdultos/b.pdf'),
      nome: 'Bondade',
      numero: '002',
      categoria: 'Partitura',
    );
    final cifraMissing = _louvor(
      pdfId: encodePdfId('ColAdultos/c.pdf'),
      nome: 'Cifra só',
      numero: '003',
      categoria: 'Cifra',
    );

    await catalogLocal.saveLouvores([
      partituraPresent,
      partituraMissing,
      cifraMissing,
    ]);

    await repository.upsert(
      pdfId: partituraPresent.pdfId,
      bytes: Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]),
      category: partituraPresent.classificacao,
      isPersistent: true,
    );

    final partituraMissingList = await useCase(CatalogMaterials.partitura);
    expect(partituraMissingList, hasLength(1));
    expect(partituraMissingList.single.pdfId, partituraMissing.pdfId);

    final cifraMissingList = await useCase(CatalogMaterials.cifra);
    expect(cifraMissingList, hasLength(1));
    expect(cifraMissingList.single.pdfId, cifraMissing.pdfId);
  });

  test('ordena por número e depois por nome', () async {
    await catalogLocal.saveLouvores([
      _louvor(pdfId: 'b', nome: 'Zebra', numero: '010', categoria: 'Partitura'),
      _louvor(pdfId: 'a', nome: 'Alpha', numero: '002', categoria: 'Partitura'),
      _louvor(pdfId: 'c', nome: 'Beta', numero: '002', categoria: 'Partitura'),
    ]);

    final missing = await useCase(CatalogMaterials.partitura);
    expect(missing.map((l) => l.pdfId).toList(), ['a', 'c', 'b']);
  });
}
