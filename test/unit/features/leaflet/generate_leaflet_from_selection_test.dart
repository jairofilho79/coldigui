import 'package:coldigui/features/leaflet/domain/entities/leaflet_document.dart';
import 'package:coldigui/features/leaflet/domain/usecases/generate_leaflet_from_selection.dart';
import 'package:coldigui/features/playlists/domain/exceptions/empty_carousel_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retorna LeafletDocument com índices e campos ordenados', () async {
    final useCase = GenerateLeafletFromSelection(
      () async => ['pdf-a', 'pdf-b'],
    );
    final generatedAt = DateTime(2026, 6, 11);

    const labels = <String, LeafletLabel>{
      'pdf-a': (numero: '001', nome: 'Louvor A'),
      'pdf-b': (numero: '002', nome: 'Louvor B'),
    };

    final doc = await useCase(
      labelOf: (id) => labels[id],
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

  test('repetição do mesmo id vira duas linhas do folheto', () async {
    final useCase = GenerateLeafletFromSelection(
      () async => ['pdf-a', 'pdf-b', 'pdf-a'],
    );

    final doc = await useCase();

    expect(doc.entries.map((e) => e.index), [1, 2, 3]);
    expect(doc.entries.map((e) => e.nome), ['pdf-a', 'pdf-b', 'pdf-a']);
  });

  test('lança EmptyCarouselException quando seleção vazia', () async {
    final useCase = GenerateLeafletFromSelection(() async => const []);

    expect(() => useCase(), throwsA(isA<EmptyCarouselException>()));
  });
}
