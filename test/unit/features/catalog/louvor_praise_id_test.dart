import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_group_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
