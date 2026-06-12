import 'package:coldigui/features/pdf_reader/data/utils/pdf_source_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = PdfSourceResolver(
    apiBaseUrl: 'https://plpcg.example.com',
  );

  group('PdfSourceResolver', () {
    test('resolve URL absoluta http(s)', () {
      const url = 'https://cdn.example.com/foo.pdf';
      final source = resolver.resolve(url);

      expect(source.kind, PdfSourceKind.remoteUrl);
      expect(source.value, url);
    });

    test('resolve path /assets/ com apiBaseUrl', () {
      final source = resolver.resolve('/assets/ColAdultos/001.pdf');

      expect(source.kind, PdfSourceKind.remoteUrl);
      expect(
        source.value,
        'https://plpcg.example.com/assets/ColAdultos/001.pdf',
      );
    });

    test('resolve path assets/ sem barra inicial', () {
      final source = resolver.resolve('assets/ColAdultos/001.pdf');

      expect(source.kind, PdfSourceKind.remoteUrl);
      expect(
        source.value,
        'https://plpcg.example.com/assets/ColAdultos/001.pdf',
      );
    });

    test('resolve convenção asset:', () {
      final source = resolver.resolve('asset:fixtures/sample.pdf');

      expect(source.kind, PdfSourceKind.asset);
      expect(source.value, 'fixtures/sample.pdf');
    });

    test('resolve path absoluto local', () {
      const path = '/tmp/local.pdf';
      final source = resolver.resolve(path);

      expect(source.kind, PdfSourceKind.localFile);
      expect(source.value, path);
    });

    test('apiBaseUrl vazio retorna path relativo', () {
      const emptyBase = PdfSourceResolver(apiBaseUrl: '');
      final source = emptyBase.resolve('/assets/foo.pdf');

      expect(source.value, '/assets/foo.pdf');
    });
  });
}
