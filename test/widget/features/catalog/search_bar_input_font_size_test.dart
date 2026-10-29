// test/widget/features/catalog/search_bar_input_font_size_test.dart
//
// Regressão do zoom no iOS: o Safari amplia a página ao focar um `<input>`
// com `font-size` abaixo de 16px, e o Flutter web replica o `TextStyle` do
// campo no `<input>` oculto que recebe o teclado. Desde o Flutter 3.47 a
// viewport injetada pelo engine é `maximum-scale=5.0` (WCAG), então nada
// mais impede esse zoom — e como o canvas captura os toques, o usuário não
// consegue desfazê-lo. Todo campo de texto do app tem de ficar em ≥16px
// (o teste da tela de Materiais favoritos cobre o outro campo explícito).
import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/features/catalog/presentation/widgets/search_bar.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('pt'),
    home: Scaffold(body: child),
  ),
);

void main() {
  test('AppTypography.input fica no limiar sem zoom do iOS', () {
    expect(
      AppTypography.input.fontSize,
      greaterThanOrEqualTo(AppTypography.iosNoZoomFontSize),
    );
  });

  testWidgets('campo de busca da Home tem fonte ≥16px', (tester) async {
    await tester.pumpWidget(
      _app(SearchBar(hintText: 'Pesquisar', onQueryChanged: (_) {})),
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(
      field.style?.fontSize,
      greaterThanOrEqualTo(AppTypography.iosNoZoomFontSize),
    );
  });
}
