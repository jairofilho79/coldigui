import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/leaflet/domain/entities/leaflet_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromCarouselItems preserva ordem e numera 1-based', () {
    const items = [
      CarouselItem(
        pdfId: 'a',
        sortOrder: 0,
        numero: '001',
        nome: 'Louvor A',
        categoria: 'Partitura',
        classificacao: 'ColAdultos',
      ),
      CarouselItem(
        pdfId: 'b',
        sortOrder: 1,
        numero: '002',
        nome: 'Louvor B',
        categoria: 'Partitura',
        classificacao: 'ColAdultos',
      ),
    ];
    final generatedAt = DateTime(2026, 6, 11, 10, 0);

    final doc = LeafletDocument.fromCarouselItems(
      items,
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

  test('fromCarouselItems ordena por sortOrder', () {
    const items = [
      CarouselItem(
        pdfId: 'b',
        sortOrder: 1,
        numero: '002',
        nome: 'B',
        categoria: '',
        classificacao: '',
      ),
      CarouselItem(
        pdfId: 'a',
        sortOrder: 0,
        numero: '001',
        nome: 'A',
        categoria: '',
        classificacao: '',
      ),
    ];

    final doc = LeafletDocument.fromCarouselItems(items);

    expect(doc.entries.map((e) => e.numero), ['001', '002']);
    expect(doc.entries.map((e) => e.nome), ['A', 'B']);
    expect(doc.entries.map((e) => e.index), [1, 2]);
  });
}
