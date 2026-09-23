import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _item = CarouselItem(
  materialId: 'x',
  index: 0,
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
  String? highlightQuery,
  String? lyricsSnippet,
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
            highlightQuery: highlightQuery,
            lyricsSnippet: lyricsSnippet,
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

  testWidgets('sem lyricsSnippet, nenhum trecho aparece', (tester) async {
    await tester.pumpWidget(_wrapChip(320));
    await tester.pumpAndSettle();

    expect(find.textContaining('chuva de bênçãos'), findsNothing);
  });

  testWidgets('com lyricsSnippet, o trecho aparece abaixo do título', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapChip(320, lyricsSnippet: '…e a chuva de bênçãos cai sobre nós…'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('chuva de bênçãos'), findsOneWidget);
  });

  testWidgets('lyricsSnippet vazio não desenha a linha do trecho', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapChip(320, lyricsSnippet: '   '));
    await tester.pumpAndSettle();

    // Sem trecho visível: só o título e a linha de metadados (2 Text.rich/Text
    // diretos do chip) — nenhum terceiro texto de conteúdo variável.
    expect(find.textContaining('…'), findsNothing);
  });

  testWidgets(
    'com highlightQuery batendo no lyricsSnippet, só o trecho casado fica '
    'dourado — o resto da linha permanece sem destaque',
    (tester) async {
      const snippet = '…e a chuva de bênçãos cai sobre nós…';
      await tester.pumpWidget(
        _wrapChip(320, highlightQuery: 'chuva', lyricsSnippet: snippet),
      );
      await tester.pumpAndSettle();

      // O título ("O fio da escarlata é o mistério") não contém "chuva", então
      // só o `HighlightedText` do trecho da letra deve ter produzido um
      // `Text.rich` com `TextSpan`s — é esse que localizamos abaixo.
      final snippetTextWidgets = tester
          .widgetList<Text>(find.byType(Text))
          .where(
            (widget) =>
                widget.textSpan?.toPlainText().contains('chuva de bênçãos') ??
                false,
          );
      expect(
        snippetTextWidgets,
        hasLength(1),
        reason: 'esperava um único Text.rich contendo o trecho da letra',
      );

      final snippetSpan = snippetTextWidgets.single.textSpan! as TextSpan;
      final children = snippetSpan.children!.cast<TextSpan>();

      // O pedaço casado ("chuva") vem com a cor ouro — se a lógica de
      // destaque regredir (ex.: highlightQuery deixar de ser propagado para o
      // HighlightedText do trecho), nenhum span vai bater aqui e o teste
      // falha.
      final matchedSpan = children.singleWhere(
        (span) => span.text == 'chuva',
        orElse: () => const TextSpan(text: ''),
      );
      expect(
        matchedSpan.text,
        'chuva',
        reason: 'nenhum TextSpan com o trecho casado "chuva" foi encontrado',
      );
      expect(matchedSpan.style?.color, AppColors.gold);

      // O restante da linha (antes e depois do match) precisa continuar sem
      // a cor de destaque — senão a linha inteira teria virado dourada em
      // vez de só o trecho casado.
      final unmatchedSpans = children.where((span) => span.text != 'chuva');
      expect(unmatchedSpans, isNotEmpty);
      for (final span in unmatchedSpans) {
        expect(
          span.style?.color,
          isNot(AppColors.gold),
          reason: 'trecho não casado "${span.text}" não deveria ser dourado',
        );
      }
      expect(
        unmatchedSpans.map((s) => s.text).join(),
        '…e a  de bênçãos cai sobre nós…',
      );
    },
  );

  testWidgets('lyricsSnippet longo trunca em uma linha só, com reticências', (
    tester,
  ) async {
    const longSnippet =
        'este é um trecho de letra propositalmente bem mais longo do que '
        'a largura disponível do chip para forçar o truncamento em uma '
        'única linha';
    await tester.pumpWidget(_wrapChip(160, lyricsSnippet: longSnippet));
    await tester.pumpAndSettle();

    final snippetText = tester
        .widgetList<Text>(find.byType(Text))
        .singleWhere((widget) => widget.data == longSnippet);

    expect(snippetText.maxLines, 1);
    expect(snippetText.overflow, TextOverflow.ellipsis);
  });

  testWidgets('chip usa AppColors.title para qualquer material', (
    tester,
  ) async {
    const item = CarouselItem(
      materialId: 'coldigom-id',
      index: 0,
      numero: '031',
      nome: 'Sal da terra',
      categoria: 'Partitura',
      classificacao: 'Country',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 360, child: CarouselLouvorChip(item: item)),
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
    expect(decoration.color, AppColors.title);
  });
}
