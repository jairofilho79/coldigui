import 'package:coldigui/features/pdf_opening/domain/usecases/open_pdf_in_reader.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/invalid_pdf_path_exception.dart';
import 'package:coldigui/features/pdf_reader/domain/usecases/open_pdf_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const openPdfInReader = OpenPdfInReader(OpenPdfDocument());

  test('OpenPdfInReader monta rota /leitor com file e titulo', () {
    final location = openPdfInReader.call(
      pdfPath: '/assets/ColAdultos/001.pdf',
      titulo: 'Aleluia',
    );

    expect(
      location,
      '/leitor?file=%2Fassets%2FColAdultos%2F001.pdf&titulo=Aleluia',
    );
  });

  test('OpenPdfInReader rejeita path inválido', () {
    expect(
      () => openPdfInReader.call(pdfPath: 'file:///etc/passwd'),
      throwsA(isA<InvalidPdfPathException>()),
    );
  });

  test('OpenPdfInReader monta rota com path absoluto local', () {
    const localPath = '/tmp/plpcg_pdfs/ColAdultos/001.pdf';
    final location = openPdfInReader.call(
      pdfPath: localPath,
      titulo: 'Aleluia',
    );

    expect(
      location,
      '/leitor?file=%2Ftmp%2Fplpcg_pdfs%2FColAdultos%2F001.pdf&titulo=Aleluia',
    );
  });
}
