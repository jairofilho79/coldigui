import 'package:coldigui/features/pdf_reader/presentation/utils/pdf_spread_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

/// Página fake com largura/altura fixas — só o que [spreadPageLayout] /
/// [defaultPdfPageLayout] leem de [PdfPage].
class _FakePdfPage extends Fake implements PdfPage {
  _FakePdfPage({this.width = 100, this.height = 150});

  @override
  final double width;

  @override
  final double height;
}

List<PdfPage> _pages(int count, {double width = 100, double height = 150}) =>
    List.generate(count, (_) => _FakePdfPage(width: width, height: height));

void main() {
  group('spreadPageLayout', () {
    test('viewport largo com 5 páginas → 3 linhas (pares 1-2, 3-4, 5)', () {
      final pages = _pages(5);
      final layout = spreadPageLayout(
        pages,
        const PdfViewerParams(),
        viewportAspect: 1.6,
        fallback: (pages, params) => fail('fallback não deveria ser chamado'),
      );

      expect(layout.pageLayouts, hasLength(5));

      // 3 linhas: y da primeira página de cada linha aumenta a cada par.
      final rowStartYs = {
        layout.pageLayouts[0].top,
        layout.pageLayouts[2].top,
        layout.pageLayouts[4].top,
      };
      expect(rowStartYs, hasLength(3));

      // Páginas da mesma linha compartilham o y.
      expect(layout.pageLayouts[0].top, layout.pageLayouts[1].top);
      expect(layout.pageLayouts[2].top, layout.pageLayouts[3].top);
    });

    test('página 1 lado a lado com a 2 — margem entre elas', () {
      const params = PdfViewerParams(margin: 8);
      final layout = spreadPageLayout(
        _pages(2),
        params,
        viewportAspect: 1.6,
        fallback: (pages, params) => fail('fallback não deveria ser chamado'),
      );

      expect(
        layout.pageLayouts[1].left,
        layout.pageLayouts[0].right + params.margin,
      );
    });

    test('última página ímpar sozinha ocupa uma linha inteira', () {
      final layout = spreadPageLayout(
        _pages(5),
        const PdfViewerParams(),
        viewportAspect: 1.6,
        fallback: (pages, params) => fail('fallback não deveria ser chamado'),
      );

      // 5 páginas → só 5 retângulos (sem página fantasma na 3ª linha).
      expect(layout.pageLayouts, hasLength(5));
    });

    test('larguras somadas no documentSize (2 páginas + 3 margens)', () {
      const params = PdfViewerParams(margin: 8);
      final layout = spreadPageLayout(
        _pages(2, width: 100),
        params,
        viewportAspect: 1.6,
        fallback: (pages, params) => fail('fallback não deveria ser chamado'),
      );

      expect(layout.documentSize.width, 100 * 2 + params.margin * 3);
    });

    test('viewport estreito (aspecto 1.0) delega ao fallback', () {
      var fallbackCalled = false;
      final pages = _pages(5);
      const params = PdfViewerParams();
      final expected = PdfPageLayout(
        pageLayouts: const [],
        documentSize: Size.zero,
      );

      final layout = spreadPageLayout(
        pages,
        params,
        viewportAspect: 1.0,
        fallback: (calledPages, calledParams) {
          fallbackCalled = true;
          expect(calledPages, same(pages));
          expect(calledParams, same(params));
          return expected;
        },
      );

      expect(fallbackCalled, isTrue);
      expect(layout, same(expected));
    });

    test('exatamente 1 página delega ao fallback mesmo em viewport largo', () {
      var fallbackCalled = false;
      spreadPageLayout(
        _pages(1),
        const PdfViewerParams(),
        viewportAspect: 1.6,
        fallback: (pages, params) {
          fallbackCalled = true;
          return defaultPdfPageLayout(pages, params);
        },
      );

      expect(fallbackCalled, isTrue);
    });

    test('aspecto igual ao mínimo (1.3) delega ao fallback', () {
      var fallbackCalled = false;
      spreadPageLayout(
        _pages(4),
        const PdfViewerParams(),
        viewportAspect: kSpreadMinViewportAspect,
        fallback: (pages, params) {
          fallbackCalled = true;
          return defaultPdfPageLayout(pages, params);
        },
      );

      expect(fallbackCalled, isTrue);
    });
  });

  group('defaultPdfPageLayout', () {
    test('coluna única — páginas empilhadas verticalmente e centralizadas', () {
      const params = PdfViewerParams(margin: 8);
      final layout = defaultPdfPageLayout(_pages(3), params);

      expect(layout.pageLayouts, hasLength(3));
      // Empilhadas: y crescente, mesma coluna (x igual, página com mesma largura).
      expect(layout.pageLayouts[0].left, layout.pageLayouts[1].left);
      expect(layout.pageLayouts[1].top, greaterThan(layout.pageLayouts[0].top));
      expect(layout.pageLayouts[2].top, greaterThan(layout.pageLayouts[1].top));
      expect(layout.documentSize.width, 100 + params.margin * 2);
      expect(layout.documentSize.height, 150 * 3 + params.margin * 4);
    });
  });
}
