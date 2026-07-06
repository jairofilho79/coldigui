import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _item = CarouselItem(
  pdfId: 'x',
  sortOrder: 0,
  numero: '203',
  nome: 'O fio da escarlata é o mistério',
  categoria: 'Partitura',
  classificacao: 'ColCIAs',
);

Widget _wrapChip(
  double width, {
  CarouselLouvorChipVariant variant = CarouselLouvorChipVariant.modal,
  bool showDragHandle = false,
  VoidCallback? onRemove,
  VoidCallback? onTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: CarouselLouvorChip(
            item: _item,
            variant: variant,
            showDragHandle: showDragHandle,
            onTap: onTap,
            onRemove: onRemove,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'exibe título com número e classificação amigável em largura ampla',
    (tester) async {
      await tester.pumpWidget(_wrapChip(360));
      await tester.pumpAndSettle();

      expect(find.textContaining('#203'), findsOneWidget);
      expect(find.textContaining('escarlata'), findsOneWidget);
      expect(find.text('Coletânea CIAs'), findsOneWidget);
      expect(find.text('Partitura'), findsOneWidget);
    },
  );

  testWidgets('modo compacto oculta textos de metadados', (tester) async {
    await tester.pumpWidget(_wrapChip(160));
    await tester.pumpAndSettle();

    expect(find.text('Coletânea CIAs'), findsNothing);
    expect(find.text('Partitura'), findsNothing);
    expect(find.byIcon(Icons.collections_bookmark_outlined), findsOneWidget);
    expect(find.byIcon(Icons.piano), findsOneWidget);
  });

  testWidgets(
    'modo médio exibe classificação e categoria com texto truncável',
    (tester) async {
      await tester.pumpWidget(_wrapChip(240));
      await tester.pumpAndSettle();

      expect(find.text('Coletânea CIAs'), findsOneWidget);
      expect(find.text('Partitura'), findsOneWidget);
      expect(find.byIcon(Icons.piano), findsOneWidget);
    },
  );

  testWidgets('topBar coloca número na linha inferior e título sem prefixo', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapChip(160, variant: CarouselLouvorChipVariant.topBar),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('escarlata'), findsOneWidget);
    expect(find.textContaining('#203 —'), findsNothing);
    expect(find.text('#203'), findsOneWidget);
  });

  testWidgets('onTap dispara ao tocar no corpo do chip', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrapChip(320, onTap: () => tapped = true));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('escarlata'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('modal exibe drag handle e botão remover', (tester) async {
    await tester.pumpWidget(
      _wrapChip(320, showDragHandle: true, onRemove: () {}),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('exibe menu compartilhar quando onShare está definido', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: CarouselLouvorChip(
                item: _item,
                onAdd: () {},
                onShare: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('exibe botão adicionar e indicador de já adicionado', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CarouselLouvorChip(item: _item, onAdd: () {}),
                  const SizedBox(height: 8),
                  const CarouselLouvorChip(item: _item, isAdded: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('chip coldigom usa fundo preto', (tester) async {
    const coldigomItem = CarouselItem(
      pdfId: 'coldigom-id',
      sortOrder: 0,
      numero: '031',
      nome: 'Sal da terra',
      categoria: 'Partitura',
      classificacao: 'Country',
      source: LouvorDataSource.coldigom,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: CarouselLouvorChip(item: coldigomItem),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(CarouselLouvorChip),
        matching: find.byType(Container).first,
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.chipColdigom);
  });
}
