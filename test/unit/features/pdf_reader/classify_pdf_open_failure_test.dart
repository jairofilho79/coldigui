import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyPdfOpenFailure (B3 — não apagar PDF offline por erro genérico)', () {
    test('magic bytes inválidos -> corrompido, mesmo com erro genérico', () {
      final result = classifyPdfOpenFailure(
        Exception('qualquer erro'),
        hasValidMagicBytes: false,
      );

      expect(result, PdfOpenFailureKind.corrupted);
    });

    test('bytes não lidos (null) com erro genérico -> readFailed (preserva)', () {
      final result = classifyPdfOpenFailure(
        Exception('qualquer erro'),
        hasValidMagicBytes: null,
      );

      expect(result, PdfOpenFailureKind.readFailed);
    });

    test('erro de formato do pdfrx (FPDF_ERR_FORMAT) -> corrompido', () {
      final result = classifyPdfOpenFailure(
        Exception('native error: FPDF_ERR_FORMAT'),
        hasValidMagicBytes: true,
      );

      expect(result, PdfOpenFailureKind.corrupted);
    });

    test('erro de formato do pdfrx ("Failed to open document") -> corrompido', () {
      final result = classifyPdfOpenFailure(
        StateError('Failed to open document'),
        hasValidMagicBytes: null,
      );

      expect(result, PdfOpenFailureKind.corrupted);
    });

    test('erro genérico com bytes válidos -> readFailed (não remover)', () {
      final result = classifyPdfOpenFailure(
        StateError('PDF sem páginas'),
        hasValidMagicBytes: true,
      );

      expect(result, PdfOpenFailureKind.readFailed);
    });

    test('timeout de storage com bytes válidos -> readFailed', () {
      final result = classifyPdfOpenFailure(
        Exception('Timeout ao ler arquivo'),
        hasValidMagicBytes: true,
      );

      expect(result, PdfOpenFailureKind.readFailed);
    });
  });
}
