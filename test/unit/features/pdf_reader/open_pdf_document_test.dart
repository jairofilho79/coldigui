import 'package:coldigui/features/pdf_reader/domain/exceptions/invalid_pdf_path_exception.dart';
import 'package:coldigui/features/pdf_reader/domain/usecases/open_pdf_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const useCase = OpenPdfDocument();

  group('OpenPdfDocument.validateFilePath', () {
    test('aceita URL https', () {
      expect(
        () => useCase.validateFilePath('https://example.com/a.pdf'),
        returnsNormally,
      );
    });

    test('aceita path /assets/', () {
      expect(
        () => useCase.validateFilePath('/assets/ColAdultos/001.pdf'),
        returnsNormally,
      );
    });

    test('aceita asset:fixtures/', () {
      expect(
        () => useCase.validateFilePath('asset:fixtures/sample.pdf'),
        returnsNormally,
      );
    });

    test('rejeita file vazio', () {
      expect(
        () => useCase.validateFilePath(''),
        throwsA(isA<InvalidPdfPathException>()),
      );
    });

    test('rejeita path traversal', () {
      expect(
        () => useCase.validateFilePath('/assets/../etc/passwd'),
        throwsA(isA<InvalidPdfPathException>()),
      );
    });

    test('rejeita esquema file:', () {
      expect(
        () => useCase.validateFilePath('file:///etc/passwd'),
        throwsA(isA<InvalidPdfPathException>()),
      );
    });

    test('rejeita esquema javascript:', () {
      expect(
        () => useCase.validateFilePath('javascript:alert(1)'),
        throwsA(isA<InvalidPdfPathException>()),
      );
    });
  });
}
