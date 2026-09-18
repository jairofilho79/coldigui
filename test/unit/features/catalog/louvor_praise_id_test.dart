import 'package:coldigui/core/database/collections/louvor_cache.dart';
import 'package:coldigui/features/catalog/data/mappers/louvor_cache_mapper.dart';
import 'package:coldigui/features/catalog/data/models/louvor_dto.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_group_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final json = <String, dynamic>{
    'nome': 'A Ti Senhor',
    'numero': '',
    'categoria': 'Partitura',
    'classificacao': 'Avulsos, GLTM',
    'pdf':
        'https://coldigom.test/assets/praises/13f78240-803a/d7dbbcb4-8929.pdf',
    'pdfId': 'MzAxMDIwMjUvQSBUaSBTZW5ob3IucGRm',
    'groupId': 'avulso:a-ti-senhor',
    'shortId': '000b',
  };

  test('DTO lê praiseId e materialId como string não vazia', () {
    final dto = LouvorDto.fromJson({
      ...json,
      'praiseId': '13f78240-803a',
      'materialId': 'd7dbbcb4-8929',
    });
    expect(dto.praiseId, '13f78240-803a');
    expect(dto.materialId, 'd7dbbcb4-8929');
    final entity = dto.toEntity();
    expect(entity.praiseId, '13f78240-803a');
    expect(entity.materialId, 'd7dbbcb4-8929');
  });

  test('DTO sem praiseId/materialId, vazio ou não-string → null', () {
    expect(LouvorDto.fromJson(json).praiseId, isNull);
    expect(LouvorDto.fromJson({...json, 'praiseId': ''}).praiseId, isNull);
    expect(LouvorDto.fromJson({...json, 'praiseId': 7}).praiseId, isNull);
    expect(LouvorDto.fromJson({...json, 'materialId': ' '}).materialId, isNull);
  });

  test('effectiveGroupId prefere praiseId, depois groupId, depois cálculo', () {
    final comPraise = Louvor.fromManifest(
      nome: 'Clamo a ti',
      numero: '3',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: '003.pdf',
      pdfId: 'id-3',
      groupId: '003:clamo-a-ti-legado',
      praiseId: 'praise-3',
    );
    expect(comPraise.effectiveGroupId, 'praise-3');

    final comGroup = Louvor.fromManifest(
      nome: 'Clamo a ti',
      numero: '3',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: '003.pdf',
      pdfId: 'id-3',
      groupId: '003:clamo-a-ti-legado',
    );
    expect(comGroup.effectiveGroupId, '003:clamo-a-ti-legado');

    final calculado = Louvor.fromManifest(
      nome: 'Clamo a ti',
      numero: '3',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: '003.pdf',
      pdfId: 'id-3',
    );
    expect(
      calculado.effectiveGroupId,
      LouvorGroupId.compute(numero: '3', nome: 'Clamo a ti'),
    );
  });

  test('cache Isar ida e volta preserva praiseId/materialId e ausência', () {
    final com = LouvorDto.fromJson({
      ...json,
      'praiseId': 'p1',
      'materialId': 'm1',
    }).toEntity();
    final sem = LouvorDto.fromJson(json).toEntity();

    expect(com.toCache().praiseId, 'p1');
    expect(com.toCache().materialId, 'm1');
    expect(com.toCache().toEntity().praiseId, 'p1');
    expect(com.toCache().toEntity().materialId, 'm1');
    expect(sem.toCache().praiseId, isNull);
    expect(sem.toCache().toEntity().materialId, isNull);
    expect(LouvorCache().praiseId, isNull);
    expect(LouvorCache().materialId, isNull);
  });
}
