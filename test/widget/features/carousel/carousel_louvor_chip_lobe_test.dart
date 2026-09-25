import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/carousel/presentation/widgets/chip_parts/peanut_lobe_border.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

const _item = CarouselItem(
  materialId: 'm1',
  index: 0,
  numero: '003',
  nome: 'Clamo a ti',
  categoria: 'Partitura',
  classificacao: 'Coro',
);

Future<void> _pump(WidgetTester tester, Widget child, {double width = 360}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

Iterable<ShapeDecoration> _shapeDecorations(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .map((box) => box.decoration)
    .whereType<ShapeDecoration>();

void main() {
  testWidgets('gomo usa a PeanutLobeBorder e não tem sombra própria', (
    tester,
  ) async {
    await _pump(
      tester,
      CarouselLouvorChip(
        item: _item,
        lobePosition: LobePosition.first,
        onAdd: () {},
      ),
    );

    final decoration = _shapeDecorations(tester).single;
    expect(
      decoration.shape,
      const PeanutLobeBorder(
        position: LobePosition.first,
        radius: carouselChipModalRadius,
      ),
    );
    expect(decoration.shadows ?? const <BoxShadow>[], isEmpty);
  });

  testWidgets('gomo e chip solto com o mesmo conteúdo têm a mesma altura', (
    tester,
  ) async {
    await _pump(
      tester,
      Column(
        children: [
          CarouselLouvorChip(
            key: const Key('solto'),
            item: _item,
            onAdd: () {},
          ),
          CarouselLouvorChip(
            key: const Key('gomo'),
            item: _item,
            onAdd: () {},
            lobePosition: LobePosition.middle,
          ),
        ],
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('gomo'))).height,
      tester.getSize(find.byKey(const Key('solto'))).height,
    );
  });

  testWidgets('etiqueta aparece e não passa de 128 px de texto', (
    tester,
  ) async {
    await _pump(
      tester,
      CarouselLouvorChip(
        item: _item,
        lobePosition: LobePosition.last,
        groupLabel: 'Coletânea · Consolo e Encorajamento',
        onAdd: () {},
      ),
    );

    final label = find.text('Coletânea · Consolo e Encorajamento');
    expect(label, findsOneWidget);
    expect(tester.getSize(label).width, lessThanOrEqualTo(128));
  });

  testWidgets('celular de 320 px com etiqueta, «novo», ícones e «+» não '
      'estoura', (tester) async {
    await _pump(
      tester,
      CarouselLouvorChip(
        item: _item,
        lobePosition: LobePosition.first,
        groupLabel: 'Avulsos · Migrados · PES',
        isNew: true,
        materialKindsGroup: catalogGroup(
          praiseId: 'p',
          number: '003',
          name: 'Clamo a ti',
          audioKinds: const {'k-audio': 'Playback'},
        ),
        onAdd: () {},
      ),
      width: 320,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('dimmed esmaece só o conteúdo, não o fundo', (tester) async {
    await _pump(
      tester,
      CarouselLouvorChip(
        item: _item,
        lobePosition: LobePosition.last,
        dimmed: true,
        onTap: () {},
      ),
    );

    final opacity = find.ancestor(
      of: find.text('#003 — Clamo a ti'),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(opacity.first).opacity, 0.45);
    expect(
      find.ancestor(
        of: find.byWidgetPredicate(
          (w) => w is DecoratedBox && w.decoration is ShapeDecoration,
        ),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
  });

  test('gomo só na variante modal e sem setas', () {
    expect(
      () => CarouselLouvorChip(
        item: _item,
        variant: CarouselLouvorChipVariant.topBar,
        lobePosition: LobePosition.first,
      ),
      throwsAssertionError,
    );
    expect(
      () => CarouselLouvorChip(
        item: _item,
        showNavArrows: true,
        lobePosition: LobePosition.first,
      ),
      throwsAssertionError,
    );
  });
}
