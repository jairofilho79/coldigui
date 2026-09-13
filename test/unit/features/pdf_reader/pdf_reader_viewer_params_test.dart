import 'package:coldigui/features/pdf_reader/presentation/utils/pdf_render_scale_policy.dart';
import 'package:coldigui/features/pdf_reader/presentation/widgets/pdf_reader_pdf_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'pdf_reader_test_helpers.dart';

const _physics = ClampingScrollPhysics();

PdfViewerParams _params({
  bool isWeb = false,
  PdfPageLayoutFunction? layoutPages,
}) {
  return buildPdfReaderViewerParams(
    isWeb: isWeb,
    scrollPhysics: _physics,
    onViewerReady: (_, _) {},
    onPageChanged: (_) {},
    layoutPages: layoutPages,
  );
}

void main() {
  group('Fase 1.2 — desliga o que partitura escaneada não usa', () {
    test('seleção de texto desligada', () {
      expect(_params().textSelectionParams?.enabled, isFalse);
    });

    test(
      'sem anotações, sem sombra por frame, sem limite de cache do PDFium',
      () {
        final params = _params();
        expect(params.annotationRenderingMode, PdfAnnotationRenderingMode.none);
        expect(params.pageDropShadow, isNull);
        expect(params.limitRenderingCache, isFalse);
      },
    );
  });

  group('Fase 1.3 — uma política de escala para todas as plataformas', () {
    test(
      'preview rasterizado no teto da política (3.0), via const provider',
      () {
        expect(_params().sizeDelegateProvider, kPdfReaderSizeDelegateProvider);
        expect(
          kPdfReaderSizeDelegateProvider.onePassRenderingScaleThreshold,
          PdfRenderScalePolicy.ceiling,
        );
        // Demais campos iguais ao default que o app já usava.
        expect(kPdfReaderSizeDelegateProvider.maxScale, 8.0);
        expect(kPdfReaderSizeDelegateProvider.minScale, 0.1);
        expect(
          kPdfReaderSizeDelegateProvider.useAlternativeFitScaleAsMinScale,
          isTrue,
        );
      },
    );

    testWidgets(
      'getPageRenderingScale segue PdfRenderScalePolicy no nativo e na web',
      (tester) async {
        late BuildContext context;
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 3),
            child: Builder(
              builder: (ctx) {
                context = ctx;
                return const SizedBox();
              },
            ),
          ),
        );
        final page = FakePdfPage(1);
        final controller = PdfViewerController();

        for (final isWeb in [false, true]) {
          final scale = _params(isWeb: isWeb).getPageRenderingScale!;
          expect(
            scale(context, page, controller, 8.0),
            3.0,
            reason: 'isWeb=$isWeb: teto absoluto',
          );
          expect(
            scale(context, page, controller, 2.5),
            2.5,
            reason: 'isWeb=$isWeb: estimativa baixa passa',
          );
        }
      },
    );

    testWidgets('em tela 1× o teto por DPR (2.0) vence', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 1),
          child: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      final scale = _params().getPageRenderingScale!;
      expect(scale(context, FakePdfPage(1), PdfViewerController(), 3.0), 2.0);
    });

    test('cache de imagem: 64 MiB na web, default do pacote no nativo', () {
      expect(kPdfWebMaxImageBytesCachedOnMemory, 64 << 20);
      expect(
        _params(isWeb: true).maxImageBytesCachedOnMemory,
        kPdfWebMaxImageBytesCachedOnMemory,
      );
      expect(
        _params().maxImageBytesCachedOnMemory,
        const PdfViewerParams().maxImageBytesCachedOnMemory,
      );
    });
  });

  group('Fase 1.4 — física de scroll por plataforma', () {
    test(
      'scrollPhysics é o que o build passou (getScrollPhysics(context))',
      () {
        expect(_params().scrollPhysics, same(_physics));
      },
    );

    test('roda/trackpad com inércia (delegate Physics)', () {
      expect(
        _params().interactionDelegateProvider,
        isA<PdfViewerScrollInteractionDelegateProviderPhysics>(),
      );
    });
  });

  group('inalterados', () {
    test('layoutPages passa direto (spread ou null)', () {
      PdfPageLayout layout(List<PdfPage> pages, PdfViewerParams params) =>
          PdfPageLayout(pageLayouts: const [], documentSize: Size.zero);
      expect(_params().layoutPages, isNull);
      expect(_params(layoutPages: layout).layoutPages, same(layout));
    });

    test('banners de loading e erro continuam definidos', () {
      final params = _params();
      expect(params.loadingBannerBuilder, isNotNull);
      expect(params.errorBannerBuilder, isNotNull);
    });
  });
}
