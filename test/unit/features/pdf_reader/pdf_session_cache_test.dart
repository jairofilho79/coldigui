import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_session_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfx/pdfx.dart';

class _DisposableController extends PdfControllerPinch {
  _DisposableController(this.label)
      : super(document: Future<PdfDocument>.value(_FakeDocument()));

  final String label;
  var wasDisposed = false;

  @override
  void dispose() {
    if (wasDisposed) return;
    wasDisposed = true;
    super.dispose();
  }
}

class _FakeDocument extends Fake implements PdfDocument {}

void main() {
  group('PdfSessionCache', () {
    test('acquire retorna controller previamente liberado', () {
      final cache = PdfSessionCache(maxSize: 2);
      final controller = _DisposableController('a');

      cache.release('/a.pdf', controller);
      expect(cache.acquire('/a.pdf'), same(controller));
      expect(cache.acquire('/a.pdf'), isNull);
    });

    test('release evicta o mais antigo ao exceder maxSize', () {
      final cache = PdfSessionCache(maxSize: 2);
      final first = _DisposableController('first');
      final second = _DisposableController('second');
      final third = _DisposableController('third');

      cache.release('/1.pdf', first);
      cache.release('/2.pdf', second);
      cache.release('/3.pdf', third);

      expect(first.wasDisposed, isTrue);
      expect(second.wasDisposed, isFalse);
      expect(third.wasDisposed, isFalse);
      expect(cache.length, 2);
    });

    test('clear descarta todos os controllers', () {
      final cache = PdfSessionCache(maxSize: 3);
      final a = _DisposableController('a');
      final b = _DisposableController('b');

      cache.release('/a.pdf', a);
      cache.release('/b.pdf', b);
      cache.clear();

      expect(a.wasDisposed, isTrue);
      expect(b.wasDisposed, isTrue);
      expect(cache.length, 0);
    });

    test('remove descarta controller da entrada', () {
      final cache = PdfSessionCache(maxSize: 2);
      final controller = _DisposableController('x');

      cache.release('/x.pdf', controller);
      cache.remove('/x.pdf');

      expect(controller.wasDisposed, isTrue);
      expect(cache.length, 0);
    });
  });
}
