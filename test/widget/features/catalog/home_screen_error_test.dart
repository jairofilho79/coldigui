import 'dart:async';

import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/presentation/pages/home_screen.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

Widget _homeErrorTestApp({
  required SharedPreferences prefs,
  required List<Override> extraOverrides,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ...extraOverrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: const HomeScreen(),
    ),
  );
}

/// `pumpAndSettle` trava com o shimmer do skeleton (animação em loop) —
/// mesmo cuidado do `home_screen_l10n_test.dart` para o estado de loading.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'HomeScreen em erro mostra botão "Tentar novamente" que invalida o manifest',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      var buildCount = 0;

      await tester.pumpWidget(
        _homeErrorTestApp(
          prefs: prefs,
          extraOverrides: [
            louvoresManifestErrorOverride(onBuild: () => buildCount++),
            connectivityStreamProvider.overrideWith(
              (ref) => const Stream<bool>.empty(),
            ),
          ],
        ),
      );
      await _settle(tester);

      expect(buildCount, 1);
      expect(find.text('Não foi possível carregar o catálogo'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Tentar novamente'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Tentar novamente'));
      await _settle(tester);

      expect(buildCount, 2);
    },
  );

  testWidgets(
    'HomeScreen recarrega automaticamente quando a conectividade volta',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      var buildCount = 0;
      final connectivityController = StreamController<bool>();
      addTearDown(connectivityController.close);

      await tester.pumpWidget(
        _homeErrorTestApp(
          prefs: prefs,
          extraOverrides: [
            louvoresManifestErrorOverride(onBuild: () => buildCount++),
            connectivityStreamProvider.overrideWith(
              (ref) => connectivityController.stream,
            ),
          ],
        ),
      );
      await _settle(tester);

      expect(buildCount, 1);

      connectivityController.add(true);
      await _settle(tester);

      expect(buildCount, 2);
    },
  );

  testWidgets(
    'HomeScreen sem erro permanece sem mensagem de erro quando a rede volta',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final connectivityController = StreamController<bool>();
      addTearDown(connectivityController.close);

      await tester.pumpWidget(
        _homeErrorTestApp(
          prefs: prefs,
          extraOverrides: [
            louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
            connectivityStreamProvider.overrideWith(
              (ref) => connectivityController.stream,
            ),
          ],
        ),
      );
      await _settle(tester);

      connectivityController.add(true);
      await _settle(tester);

      expect(find.text('Não foi possível carregar o catálogo'), findsNothing);
    },
  );
}
