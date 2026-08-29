import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/chords/data/providers/chord_providers.dart';
import 'package:coldigui/features/chords/domain/usecases/parse_chordpro.dart';
import 'package:coldigui/features/chords/presentation/pages/chord_reader_screen.dart';
import 'package:coldigui/features/chords/presentation/providers/chord_reader_mode_provider.dart';
import 'package:coldigui/features/chords/presentation/theme/chord_reader_theme.dart';
import 'package:coldigui/features/chords/presentation/widgets/chordpro_view.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _r2Key = 'assets/praises/p1/m1.chord';

Future<SharedPreferences> _pump(
  WidgetTester tester, {
  required bool available,
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  final song = parseChordPro(
    '{title: Comigo habita}\n{key: Eb}\n\nA [Bb]noite ha[Cm]bi\n',
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        chordSongProvider.overrideWith(
          (ref, key) async => available ? song : null,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Locale fixo: o default do flutter_test e ingles, e os asserts
        // abaixo esperam as strings em portugues.
        locale: const Locale('pt'),
        home: ChordReaderScreen(
          queryParams: {'pdfId': encodePdfId(_r2Key), 'titulo': 'Comigo habita'},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

void main() {
  testWidgets('renderiza a cifra disponivel', (tester) async {
    await _pump(tester, available: true);

    expect(find.byType(ChordProView), findsOneWidget);
    expect(find.text('Comigo habita'), findsWidgets);
    expect(find.byKey(chordBarKey(0, 1)), findsOneWidget);
  });

  testWidgets('mostra indisponivel quando nao ha arquivo', (tester) async {
    await _pump(tester, available: false);

    expect(find.byType(ChordProView), findsNothing);
    expect(find.text('Cifra ainda não disponível'), findsOneWidget);
  });

  testWidgets('toggle alterna o tema do leitor', (tester) async {
    final prefs = await _pump(tester, available: true);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChordReaderScreen)),
    );
    expect(container.read(chordReaderModeProvider), ChordReaderMode.light);

    await tester.tap(find.byTooltip('Alternar tema do leitor'));
    await tester.pumpAndSettle();

    expect(container.read(chordReaderModeProvider), ChordReaderMode.dark);
    // O requisito e a persistencia, nao o estado em memoria.
    expect(prefs.getString(StorageKeys.chordReaderMode), 'dark');
  });
}
