import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:coldigui/features/gestures/presentation/theme/gesture_reader_theme.dart';
import 'package:coldigui/features/gestures/presentation/widgets/section_label_view.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _palette = GestureReaderMode.light.palette;

Future<void> _pump(
  WidgetTester tester,
  SectionLabel label, {
  Locale locale = const Locale('pt'),
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: SectionLabelView(
            label: label,
            fontSize: 20,
            palette: _palette,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('«coro» em caixa alta, pequeno, na cor da paleta', (
    tester,
  ) async {
    await _pump(tester, const SectionLabel.chorus());
    final text = tester.widget<Text>(find.text('CORO'));
    expect(text.style?.color, _palette.sectionLabel);
    expect(text.style?.fontSize, closeTo(14, 0.01)); // 20 × 0.7
    expect(text.style?.fontWeight, FontWeight.w600);
  });

  testWidgets('«2ª vez» em pt, «TIME 2» em en', (tester) async {
    await _pump(tester, const SectionLabel.pass(2));
    expect(find.text('2ª VEZ'), findsOneWidget);
    await _pump(tester, const SectionLabel.pass(2), locale: const Locale('en'));
    expect(find.text('TIME 2'), findsOneWidget);
  });
}
