import 'package:coldigui/features/leaflet/domain/entities/leaflet_document.dart';
import 'package:coldigui/features/leaflet/domain/usecases/generate_leaflet_from_pdf_ids.dart';
import 'package:coldigui/features/playlists/domain/exceptions/empty_carousel_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const useCase = GenerateLeafletFromPdfIds();
  const labels = <String, LeafletLabel>{
    'pdf-a': (numero: '001', nome: 'Louvor A'),
    'pdf-b': (numero: '002', nome: 'Louvor B'),
  };

  test('retorna LeafletDocument na ordem dos pdfIds', () {
    final generatedAt = DateTime(2026, 6, 11);
    final doc = useCase(
      pdfIds: ['pdf-b', 'pdf-a'],
      labelOf: (id) => labels[id],
      generatedAt: generatedAt,
    );

    expect(doc.generatedAt, generatedAt);
    expect(doc.entries.length, 2);
    expect(doc.entries[0].numero, '002');
    expect(doc.entries[0].nome, 'Louvor B');
    expect(doc.entries[1].numero, '001');
    expect(doc.entries[1].nome, 'Louvor A');
  });

  test('lança EmptyCarouselException quando pdfIds vazio', () {
    expect(
      () => useCase(pdfIds: const []),
      throwsA(isA<EmptyCarouselException>()),
    );
  });
}
