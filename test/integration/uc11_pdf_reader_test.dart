import 'package:coldigui/features/pdf_reader/data/utils/pdf_source_resolver.dart';
import 'package:coldigui/features/pdf_reader/domain/usecases/open_pdf_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const openPdf = OpenPdfDocument();
  const resolver = PdfSourceResolver(apiBaseUrl: 'https://plpcg.example.com');

  test('UC-11 — pipeline validação + resolução asset fixture', () {
    const filePath = 'asset:fixtures/sample.pdf';

    expect(() => openPdf.validateFilePath(filePath), returnsNormally);

    final source = resolver.resolve(filePath);
    expect(source.kind, PdfSourceKind.asset);
    expect(source.value, 'fixtures/sample.pdf');
  });

  test('UC-11 — pipeline validação + resolução URL remota /assets/', () {
    const filePath = '/assets/ColAdultos/001.pdf';

    expect(() => openPdf.validateFilePath(filePath), returnsNormally);

    final source = resolver.resolve(filePath);
    expect(source.kind, PdfSourceKind.remoteUrl);
    expect(
      source.value,
      'https://plpcg.example.com/assets/ColAdultos/001.pdf',
    );
  });
}
