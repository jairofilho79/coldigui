import 'package:coldigui/core/theme/brand_fade_page_transitions_builder.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BrandFadePageTransitionsBuilder.frameAt', () {
    const mid = BrandFadePageTransitionsBuilder.kMidpoint;
    const startScale = BrandFadePageTransitionsBuilder.kStartScale;

    test('início: página nova invisível e nenhuma cor por cima', () {
      final f = BrandFadePageTransitionsBuilder.frameAt(0);
      expect(f.pageVisible, isFalse);
      expect(f.overlay, 0);
    });

    test('1ª fase: cor sobe sobre a página de baixo, nova segue oculta', () {
      final a = BrandFadePageTransitionsBuilder.frameAt(mid * 0.25);
      final b = BrandFadePageTransitionsBuilder.frameAt(mid * 0.75);
      expect(a.pageVisible, isFalse);
      expect(b.pageVisible, isFalse);
      expect(a.overlay, greaterThan(0));
      expect(b.overlay, greaterThan(a.overlay));
      expect(b.overlay, lessThan(1));
    });

    test('meio: cor cobre tudo e a página nova passa a ser pintada', () {
      final f = BrandFadePageTransitionsBuilder.frameAt(mid);
      expect(f.pageVisible, isTrue);
      expect(f.overlay, 1);
      expect(f.scale, startScale);
    });

    test('2ª fase: cor desce e a página cresce até 100%', () {
      final a = BrandFadePageTransitionsBuilder.frameAt(mid + (1 - mid) * 0.3);
      final b = BrandFadePageTransitionsBuilder.frameAt(mid + (1 - mid) * 0.7);
      expect(a.pageVisible, isTrue);
      expect(b.overlay, lessThan(a.overlay));
      expect(b.scale, greaterThan(a.scale));
      expect(a.scale, greaterThan(startScale));
    });

    test('fim: página inteira, sem cor e sem escala', () {
      final f = BrandFadePageTransitionsBuilder.frameAt(1);
      expect(f.pageVisible, isTrue);
      expect(f.overlay, 0);
      expect(f.scale, 1);
    });

    test('nada se desloca: escala nunca sai de [kStartScale, 1]', () {
      for (var i = 0; i <= 100; i++) {
        final f = BrandFadePageTransitionsBuilder.frameAt(i / 100);
        expect(f.scale, inInclusiveRange(startScale, 1));
        expect(f.overlay, inInclusiveRange(0, 1));
      }
    });
  });

  group('buildTransitions', () {
    Future<AnimationController> pumpRoute(
      WidgetTester tester, {
      bool disableAnimations = false,
    }) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 240),
      );
      addTearDown(controller.dispose);
      final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) =>
                  const BrandFadePageTransitionsBuilder().buildTransitions(
                    route,
                    context,
                    controller,
                    kAlwaysDismissedAnimation,
                    const SizedBox(key: Key('page')),
                  ),
            ),
          ),
        ),
      );
      return controller;
    }

    Color overlayColor(WidgetTester tester) {
      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
      expect(box.position, DecorationPosition.foreground);
      return (box.decoration as BoxDecoration).color!;
    }

    double pageOpacity(WidgetTester tester) =>
        tester.widget<Opacity>(find.byType(Opacity)).opacity;

    testWidgets('cor é o marrom do fundo, nunca o creme do surface', (
      tester,
    ) async {
      final controller = await pumpRoute(tester);
      controller.value = BrandFadePageTransitionsBuilder.kMidpoint;
      await tester.pump();
      expect(overlayColor(tester), AppColors.background);
      expect(pageOpacity(tester), 1);
    });

    testWidgets('página só liga/desliga (sem opacidade parcial)', (
      tester,
    ) async {
      final controller = await pumpRoute(tester);
      for (var i = 0; i <= 20; i++) {
        controller.value = i / 20;
        await tester.pump();
        expect(pageOpacity(tester), anyOf(0.0, 1.0));
      }
    });

    testWidgets('reduzir movimento: página inteira em qualquer instante', (
      tester,
    ) async {
      final controller = await pumpRoute(tester, disableAnimations: true);
      controller.value = 0.1;
      await tester.pump();
      expect(pageOpacity(tester), 1);
      expect(overlayColor(tester).a, 0);
      expect(find.byKey(const Key('page')), findsOneWidget);
    });
  });
}
