import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_group_id.dart';
import 'package:flutter_test/flutter_test.dart';

/// Valores de [Louvor.categoria] usados nos cenários.
const _partitura = 'Partitura';
const _cifraNivelI = 'Cifra nível I';

Louvor _louvor({
  required String nome,
  required String categoria,
  required String classificacao,
  String numero = '100',
  String pdfId = 'id',
  String groupId = '',
}) => Louvor.fromManifest(
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

    test('compute normaliza zeros à esquerda', () {
      expect(
        LouvorGroupId.compute(numero: '003', nome: 'Clamo a ti'),
        LouvorGroupId.compute(numero: '3', nome: 'Clamo a ti'),
      );
    });
  });

  group('LouvorGroup.fromLouvores', () {
    const group = LouvorGroup.fromLouvores;

    test('agrupa materiais do mesmo louvor em seções por classificação', () {
      final louvores = [
        _louvor(
          nome: 'Cristo sente',
          categoria: _partitura,
          classificacao: 'Coletânea CIAs',
          pdfId: 'p1',
        ),
        _louvor(
          nome: 'Cristo sente',
          categoria: _cifraNivelI,
          classificacao: 'Coletânea CIAs',
          pdfId: 'c1',
        ),
        _louvor(
          nome: 'Cristo sente',
          categoria: _partitura,
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
          categoria: _partitura,
          classificacao: 'Coletânea CIAs',
          pdfId: 'a',
          numero: '10',
        ),
        _louvor(
          nome: 'Vamos lavar as vestes',
          categoria: _partitura,
          classificacao: 'Coletânea Adultos',
          pdfId: 'b',
          numero: '10',
        ),
      ];

      expect(group(louvores), hasLength(2));
    });

    test('003 e 3 no mesmo nome agrupam no mesmo groupId', () {
      final louvores = [
        _louvor(
          nome: 'Clamo a ti',
          categoria: _partitura,
          classificacao: 'Coletânea CIAs',
          pdfId: 'a',
          numero: '003',
        ),
        _louvor(
          nome: 'Clamo a ti',
          categoria: _cifraNivelI,
          classificacao: 'Coletânea CIAs',
          pdfId: 'b',
          numero: '3',
        ),
      ];

      expect(group(louvores), hasLength(1));
      expect(group(louvores).first.numero, '003');
    });

    test('sortByNumber false preserva ordem de entrada', () {
      final louvores = [
        _louvor(
          nome: 'A Ti Senhor',
          categoria: _partitura,
          classificacao: 'Coletânea',
          pdfId: 'top',
          numero: '500',
        ),
        _louvor(
          nome: 'Abraão',
          categoria: _partitura,
          classificacao: 'Coletânea',
          pdfId: 'low',
          numero: '001',
        ),
      ];

      final sorted = group(louvores);
      expect(sorted.map((g) => g.nome).toList(), ['Abraão', 'A Ti Senhor']);

      final preserved = group(louvores, sortByNumber: false);
      expect(preserved.map((g) => g.nome).toList(), ['A Ti Senhor', 'Abraão']);
    });
  });
}
