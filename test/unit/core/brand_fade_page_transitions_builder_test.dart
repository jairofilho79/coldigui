import 'dart:async';

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

  group('pop (BrandFadePageTransitionsBuilder.popFrameAt/revealScaleAt)', () {
    const popMid = BrandFadePageTransitionsBuilder.kPopMidpoint;
    const startScale = BrandFadePageTransitionsBuilder.kStartScale;

    test('tela de cima nunca encolhe: cor cobre sem mexer na escala', () {
      for (var i = 0; i <= 100; i++) {
        expect(BrandFadePageTransitionsBuilder.popFrameAt(i / 100).scale, 1);
      }
    });

    test(
      '1ª fase: cor sobe rápido sobre a tela de cima, que segue pintada',
      () {
        final a = BrandFadePageTransitionsBuilder.popFrameAt(popMid * 0.25);
        final b = BrandFadePageTransitionsBuilder.popFrameAt(popMid * 0.75);
        expect(a.pageVisible, isTrue);
        expect(b.pageVisible, isTrue);
        expect(b.overlay, greaterThan(a.overlay));
        // Rápido no começo (easeOut), não arrastado como o push invertido.
        expect(a.overlay, greaterThan(0.25));
      },
    );

    test('meio: cor cobre tudo e a tela de cima some', () {
      final f = BrandFadePageTransitionsBuilder.popFrameAt(popMid);
      expect(f.pageVisible, isFalse);
      expect(f.overlay, 1);
    });

    test('2ª fase: cor desce rápido no começo revelando a tela de baixo', () {
      final a = BrandFadePageTransitionsBuilder.popFrameAt(
        popMid + (1 - popMid) * 0.25,
      );
      expect(a.pageVisible, isFalse);
      expect(a.overlay, lessThan(0.75));
    });

    test('fim: sem cor', () {
      expect(BrandFadePageTransitionsBuilder.popFrameAt(1).overlay, 0);
    });

    test('tela de baixo: parada até o meio, depois cresce até 100%', () {
      expect(BrandFadePageTransitionsBuilder.revealScaleAt(0), startScale);
      expect(
        BrandFadePageTransitionsBuilder.revealScaleAt(popMid * 0.9),
        startScale,
      );
      final a = BrandFadePageTransitionsBuilder.revealScaleAt(
        popMid + (1 - popMid) * 0.3,
      );
      final b = BrandFadePageTransitionsBuilder.revealScaleAt(
        popMid + (1 - popMid) * 0.7,
      );
      expect(a, greaterThan(startScale));
      expect(b, greaterThan(a));
      expect(BrandFadePageTransitionsBuilder.revealScaleAt(1), 1);
    });
  });

  group('buildTransitions', () {
    Future<AnimationController> pumpRoute(
      WidgetTester tester, {
      bool disableAnimations = false,
      Animation<double> secondaryAnimation = kAlwaysDismissedAnimation,
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
                    secondaryAnimation,
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

    double pageScale(WidgetTester tester) => tester
        .widget<Transform>(
          find.ancestor(
            of: find.byKey(const Key('page')),
            matching: find.byType(Transform),
          ),
        )
        .transform
        .storage[0];

    Color backdropColor(WidgetTester tester) =>
        tester.widget<ColoredBox>(find.byType(ColoredBox)).color;

    AnimationController secondary() {
      final c = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 240),
      );
      addTearDown(c.dispose);
      return c;
    }

    testWidgets('pop: tela de cima não encolhe (sem borda da de baixo)', (
      tester,
    ) async {
      final controller = await pumpRoute(tester);
      controller.value = 1;
      unawaited(controller.reverse());
      for (var ms = 0; ms <= 240; ms += 20) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(pageScale(tester), 1);
      }
      await tester.pumpAndSettle();
    });

    testWidgets('pop: tela de baixo cresce sobre fundo marrom', (tester) async {
      final below = secondary()..value = 1;
      final controller = await pumpRoute(tester, secondaryAnimation: below);
      controller.value = 1;
      await tester.pump();
      unawaited(below.reverse());
      // Já na 2ª fase (revelação).
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 150));
      expect(pageScale(tester), lessThan(1));
      expect(pageScale(tester), greaterThan(0.98));
      expect(backdropColor(tester), AppColors.background);
      await tester.pumpAndSettle();
      expect(pageScale(tester), 1);
    });

    testWidgets('push: tela de baixo fica parada', (tester) async {
      final below = secondary();
      final controller = await pumpRoute(tester, secondaryAnimation: below);
      controller.value = 1;
      unawaited(below.forward());
      for (var ms = 0; ms <= 240; ms += 20) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(pageScale(tester), 1);
      }
      await tester.pumpAndSettle();
    });

    // Telas do shell (ex.: Perfil) não pintam fundo; sem isto a rota de
    // baixo aparece através da de cima durante a transição («fantasma»).
    testWidgets('página tem fundo marrom opaco, escondido junto com ela', (
      tester,
    ) async {
      final controller = await pumpRoute(tester);
      for (var i = 0; i <= 20; i++) {
        controller.value = i / 20;
        await tester.pump();
        expect(backdropColor(tester), AppColors.background);
        expect(
          find.ancestor(
            of: find.byType(ColoredBox),
            matching: find.byType(Opacity),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('pop: tela de cima segue opaca enquanto a cor sobe', (
      tester,
    ) async {
      final controller = await pumpRoute(tester);
      controller.value = 1;
      unawaited(controller.reverse());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(pageOpacity(tester), 1);
      expect(backdropColor(tester), AppColors.background);
      await tester.pumpAndSettle();
    });

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
