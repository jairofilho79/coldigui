import 'package:coldigui/core/database/collections/louvor_cache.dart';
import 'package:coldigui/features/catalog/data/mappers/louvor_cache_mapper.dart';
import 'package:coldigui/features/catalog/data/models/louvor_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final json = <String, dynamic>{
    'nome': 'Teste',
    'numero': '1',
    'categoria': 'Partitura',
    'classificacao': 'ColAdultos',
    'pdf': '001.pdf',
    'pdfId': 'Q29sQWR1bHRvcy8wMDEucGRm',
    'groupId': '001:teste',
  };

  test('DTO lê shortId como string e preserva "0000"', () {
    final dto = LouvorDto.fromJson({...json, 'shortId': '0000'});
    expect(dto.shortId, '0000');
    expect(dto.toEntity().shortId, '0000');
  });

  test('DTO sem shortId → null (catálogo antigo)', () {
    final dto = LouvorDto.fromJson(json);
    expect(dto.shortId, isNull);
    expect(dto.toEntity().shortId, isNull);
  });

  test('DTO ignora shortId que não é string (nunca converte número)', () {
    final dto = LouvorDto.fromJson({...json, 'shortId': 0});
    expect(dto.shortId, isNull);
  });

  test('cache Isar ida e volta preserva shortId e ausência', () {
    final com = LouvorDto.fromJson({...json, 'shortId': '1a2f'}).toEntity();
    final sem = LouvorDto.fromJson(json).toEntity();
    expect(com.toCache().shortId, '1a2f');
    expect(com.toCache().toEntity().shortId, '1a2f');
    expect(sem.toCache().shortId, isNull);
    expect(sem.toCache().toEntity().shortId, isNull);
    expect(LouvorCache().shortId, isNull);
  });
}
