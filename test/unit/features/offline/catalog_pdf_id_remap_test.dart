import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/offline/domain/utils/catalog_pdf_id_remap.dart';
import 'package:flutter_test/flutter_test.dart';

Louvor _louvor({
  required String nome,
  required String numero,
  required String categoria,
  required String pdfId,
  String groupId = '',
}) {
  return Louvor.fromManifest(
    nome: nome,
    numero: numero,
    categoria: categoria,
    classificacao: 'ColAdultos',
    pdf: '$pdfId.pdf',
    pdfId: pdfId,
    groupId: groupId,
  );
}

void main() {
  test('detecta substituição pelo mesmo groupId e material', () {
    final previous = [
      _louvor(
        nome: 'Clamo a ti',
        numero: '3',
        categoria: 'Partitura',
        pdfId: 'old-id',
        groupId: '003:clamo-a-ti',
      ),
    ];
    final updated = [
      _louvor(
        nome: 'Clamo a ti',
        numero: '3',
        categoria: 'Partitura',
        pdfId: 'new-id',
        groupId: '003:clamo-a-ti',
      ),
    ];

    final remappings = computeCatalogPdfIdRemappings(
      previousLouvores: previous,
      newLouvores: updated,
    );

    expect(remappings, {'old-id': 'new-id'});
  });

  test('ignora quando pdfId não mudou', () {
    final louvor = _louvor(
      nome: 'Louvor',
      numero: '1',
      categoria: 'Cifra',
      pdfId: 'same-id',
    );

    final remappings = computeCatalogPdfIdRemappings(
      previousLouvores: [louvor],
      newLouvores: [louvor],
    );

    expect(remappings, isEmpty);
  });

  test('remapPdfIdList substitui ids obsoletos preservando ordem', () {
    final remapped = remapPdfIdList(
      ['a', 'b', 'c'],
      {'b': 'b2'},
    );

    expect(remapped, ['a', 'b2', 'c']);
  });
}
