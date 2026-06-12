import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/usecases/group_louvores_by_material.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_group_id.dart';
import 'package:flutter_test/flutter_test.dart';

Louvor _louvor({
  required String nome,
  required String categoria,
  required String classificacao,
  String numero = '100',
  String pdfId = 'id',
  String groupId = '',
}) =>
    Louvor.fromManifest(
      nome: nome,
      numero: numero,
      categoria: categoria,
      classificacao: classificacao,
      pdf: '$numero.pdf',
      pdfId: pdfId,
      groupId: groupId,
    );

void main() {
  group('LouvorGroupId', () {
    test('compute com numero', () {
      expect(
        LouvorGroupId.compute(numero: '609', nome: 'Senhor, meu Deus'),
        '609:senhor-meu-deus',
      );
    });

    test('compute avulso sem numero', () {
      expect(
        LouvorGroupId.compute(numero: '', nome: 'Abriga-me'),
        'avulso:abriga-me',
      );
    });
  });

  group('GroupLouvoresByMaterial', () {
    const group = GroupLouvoresByMaterial();

    test('agrupa materiais do mesmo louvor em seções por classificação', () {
      final louvores = [
        _louvor(
          nome: 'Cristo sente',
          categoria: CatalogMaterials.partitura,
          classificacao: 'Coletânea CIAs',
          pdfId: 'p1',
        ),
        _louvor(
          nome: 'Cristo sente',
          categoria: CatalogMaterials.cifraNivelI,
          classificacao: 'Coletânea CIAs',
          pdfId: 'c1',
        ),
        _louvor(
          nome: 'Cristo sente',
          categoria: CatalogMaterials.partitura,
          classificacao: 'Coletânea CIAs (Evento X)',
          pdfId: 'p2',
        ),
      ];

      final groups = group(louvores);
      expect(groups, hasLength(1));
      expect(groups.first.totalMaterials, 3);
      expect(groups.first.sections, hasLength(2));
      expect(groups.first.sections.first.materials, hasLength(2));
    });

    test('números iguais com nomes diferentes permanecem grupos distintos', () {
      final louvores = [
        _louvor(
          nome: 'Clama ó igreja',
          categoria: CatalogMaterials.partitura,
          classificacao: 'Coletânea CIAs',
          pdfId: 'a',
          numero: '10',
        ),
        _louvor(
          nome: 'Vamos lavar as vestes',
          categoria: CatalogMaterials.partitura,
          classificacao: 'Coletânea Adultos',
          pdfId: 'b',
          numero: '10',
        ),
      ];

      expect(group(louvores), hasLength(2));
    });
  });
}
