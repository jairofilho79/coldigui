import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/carousel/presentation/widgets/chip_parts/chip_nav_zone.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _pdfItem = CarouselItem(
  materialId: 'a',
  index: 0,
  numero: '047',
  nome: 'Shekinah',
  categoria: 'Coro',
  classificacao: 'ColAdultos',
);

const _audioItem = CarouselItem(
  materialId: 'a.mp3',
  kind: MaterialKind.audio,
  index: 1,
  numero: '047',
  nome: 'Shekinah',
  categoria: 'Coro',
  classificacao: 'ColAdultos',
);

/// Áudio cuja faixa ainda não está em cache: `categoria` vem vazia do
/// manifest, mas o ícone tem que continuar sendo o de áudio — `item.kind`
/// manda, não a heurística de `categoria` (essa só vale para PDF/unknown).
const _audioItemNoCategoria = CarouselItem(
  materialId: 'b.mp3',
  kind: MaterialKind.audio,
  index: 2,
  numero: '048',
  nome: 'Aleluia',
  categoria: '',
  classificacao: 'ColAdultos',
);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('pt'),
  home: Scaffold(body: SizedBox(width: 320, child: child)),
);

void main() {
  testWidgets('setas sempre presentes; apagadas e inertes nos extremos', (
    tester,
  ) async {
    var previous = 0;
    var next = 0;
    await tester.pumpWidget(
      _wrap(
        CarouselLouvorChip(
          item: _pdfItem,
          variant: CarouselLouvorChipVariant.topBar,
          showNavArrows: true,
          canGoPrevious: false,
          canGoNext: true,
          onPrevious: () => previous++,
          onNext: () => next++,
        ),
      ),
    );

    expect(find.byType(ChipNavZone), findsNWidgets(2));
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    final left = tester.widget<Opacity>(
      find.ancestor(
        of: find.byIcon(Icons.chevron_left),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(left.opacity, 0.35);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();

    expect(previous, 0);
    expect(next, 1);
  });

  testWidgets('sem showNavArrows não há zonas de seta', (tester) async {
    await tester.pumpWidget(_wrap(const CarouselLouvorChip(item: _pdfItem)));
    expect(find.byType(ChipNavZone), findsNothing);
  });

  testWidgets('toque no corpo chama onTap, não as setas', (tester) async {
    var tapped = 0;
    var next = 0;
    await tester.pumpWidget(
      _wrap(
        CarouselLouvorChip(
          item: _pdfItem,
          variant: CarouselLouvorChipVariant.topBar,
          showNavArrows: true,
          canGoNext: true,
          onTap: () => tapped++,
          onNext: () => next++,
        ),
      ),
    );

    await tester.tap(find.text('Shekinah'));
    await tester.pump();
    expect(tapped, 1);
    expect(next, 0);
  });

  testWidgets('entrada de áudio usa o ícone de áudio na linha de metadados', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const CarouselLouvorChip(
          item: _audioItem,
          variant: CarouselLouvorChipVariant.topBar,
        ),
      ),
    );
    expect(find.byIcon(LouvorMaterialIcons.audio), findsOneWidget);
    expect(find.byIcon(Icons.piano), findsNothing);
  });

  testWidgets(
    'entrada de áudio sem categoria (fora do cache) ainda usa o ícone de '
    'áudio',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CarouselLouvorChip(
            item: _audioItemNoCategoria,
            variant: CarouselLouvorChipVariant.topBar,
          ),
        ),
      );
      expect(find.byIcon(LouvorMaterialIcons.audio), findsOneWidget);
    },
  );
}
