import 'package:coldigui/features/carousel/presentation/widgets/carousel_bar_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('com legenda: ícone + texto, sem tooltip', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      _wrap(
        CarouselBarActionButton(
          icon: Icons.file_open_outlined,
          label: 'Abrir',
          onPressed: () => pressed++,
        ),
      ),
    );

    expect(find.byIcon(Icons.file_open_outlined), findsOneWidget);
    expect(find.text('Abrir'), findsOneWidget);
    expect(find.byTooltip('Abrir'), findsNothing);

    await tester.tap(find.text('Abrir'));
    expect(pressed, 1);
  });

  testWidgets('com legenda e tooltip explícito: mantém o tooltip (Minor #10)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        CarouselBarActionButton(
          icon: Icons.delete_outline,
          label: 'Limpar',
          tooltip: 'Limpar seleção',
          onPressed: () {},
        ),
      ),
    );

    expect(find.text('Limpar'), findsOneWidget);
    // A legenda curta («Limpar») não diz "seleção" sozinha — o tooltip
    // continua disponível em barra larga, não só no modo ícone.
    expect(find.byTooltip('Limpar seleção'), findsOneWidget);
  });

  testWidgets('sem legenda: IconButton com tooltip', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CarouselBarActionButton(
          icon: Icons.queue_music,
          label: 'Lista',
          showLabel: false,
          onPressed: () {},
        ),
      ),
    );

    expect(find.text('Lista'), findsNothing);
    expect(find.byTooltip('Lista'), findsOneWidget);
    expect(find.byType(IconButton), findsOneWidget);
  });

  testWidgets('grupo envolve os filhos num container tintado', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CarouselBarActionGroup(
          tint: Colors.red,
          children: [
            CarouselBarActionButton(
              icon: Icons.delete_outline,
              label: 'Limpar',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    expect(find.byType(CarouselBarActionGroup), findsOneWidget);
    expect(find.text('Limpar'), findsOneWidget);
  });
}
