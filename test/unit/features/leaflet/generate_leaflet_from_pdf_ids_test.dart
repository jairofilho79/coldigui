import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/leaflet/domain/usecases/generate_leaflet_from_pdf_ids.dart';
import 'package:coldigui/features/playlists/domain/exceptions/empty_carousel_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const useCase = GenerateLeafletFromPdfIds();
  const metadata = {
    'pdf-a': CarouselItemMetadata(
      numero: '001',
      nome: 'Louvor A',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
    ),
    'pdf-b': CarouselItemMetadata(
      numero: '002',
      nome: 'Louvor B',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
    ),
  };

  test('retorna LeafletDocument na ordem dos pdfIds', () {
    final generatedAt = DateTime(2026, 6, 11);
    final doc = useCase(
      pdfIds: ['pdf-b', 'pdf-a'],
      pdfIdToMetadata: metadata,
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
