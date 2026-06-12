import 'package:coldigui/features/pdf_opening/domain/utils/is_local_pdf_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isLocalPdfPath', () {
    test('retorna false para URL http(s)', () {
      expect(isLocalPdfPath('https://cdn.example.com/foo.pdf'), isFalse);
      expect(isLocalPdfPath('http://cdn.example.com/foo.pdf'), isFalse);
    });

    test('retorna false para asset:', () {
      expect(isLocalPdfPath('asset:fixtures/sample.pdf'), isFalse);
    });

    test('retorna false para /assets/ e assets/', () {
      expect(isLocalPdfPath('/assets/ColAdultos/001.pdf'), isFalse);
      expect(isLocalPdfPath('assets/ColAdultos/001.pdf'), isFalse);
    });

    test('retorna true para path absoluto local', () {
      expect(
        isLocalPdfPath('/var/mobile/plpcg_pdfs/ColAdultos/001.pdf'),
        isTrue,
      );
      expect(isLocalPdfPath('/tmp/local.pdf'), isTrue);
    });

    test('retorna false para string vazia', () {
      expect(isLocalPdfPath(''), isFalse);
      expect(isLocalPdfPath('   '), isFalse);
    });
  });
}
