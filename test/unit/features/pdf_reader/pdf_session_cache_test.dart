import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_session_cache.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pdf_reader_test_helpers.dart';

void main() {
  group('PdfSessionCache', () {
    test('acquire retorna handle previamente liberado', () {
      final cache = PdfSessionCache(maxSize: 2);
      final handle = createTrackableHandle();

      cache.release('/a.pdf', handle);
      expect(cache.acquire('/a.pdf'), same(handle));
      expect(cache.acquire('/a.pdf'), isNull);
    });

    test('release evicta o mais antigo ao exceder maxSize', () {
      final cache = PdfSessionCache(maxSize: 2);
      final first = createTrackableHandle();
      final second = createTrackableHandle();
      final third = createTrackableHandle();

      cache.release('/1.pdf', first);
      cache.release('/2.pdf', second);
      cache.release('/3.pdf', third);

      expect(first.wasDisposed, isTrue);
      expect(second.wasDisposed, isFalse);
      expect(third.wasDisposed, isFalse);
      expect(cache.length, 2);
    });

    test('clear descarta todos os handles', () {
      final cache = PdfSessionCache(maxSize: 3);
      final a = createTrackableHandle();
      final b = createTrackableHandle();

      cache.release('/a.pdf', a);
      cache.release('/b.pdf', b);
      cache.clear();

      expect(a.wasDisposed, isTrue);
      expect(b.wasDisposed, isTrue);
      expect(cache.length, 0);
    });

    test('remove descarta handle da entrada', () {
      final cache = PdfSessionCache(maxSize: 2);
      final handle = createTrackableHandle();

      cache.release('/x.pdf', handle);
      cache.remove('/x.pdf');

      expect(handle.wasDisposed, isTrue);
      expect(cache.length, 0);
    });
  });
}
