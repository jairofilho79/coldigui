import 'dart:async';

import 'package:coldigui/core/widgets/deferred_route_loader.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: child,
    );
  }

  testWidgets('mostra mensagem de loading localizada por padrão', (
    tester,
  ) async {
    final neverCompletes = Completer<void>();
    addTearDown(neverCompletes.complete);

    await tester.pumpWidget(
      wrap(
        DeferredRouteLoader(
          load: () => neverCompletes.future,
          builder: () => const Text('conteúdo'),
        ),
      ),
    );

    expect(find.text('Carregando…'), findsOneWidget);
  });

  testWidgets(
    'em erro, exibe mensagem localizada e "Tentar novamente" chama load() de novo',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        wrap(
          DeferredRouteLoader(
            load: () async {
              calls++;
              if (calls == 1) {
                throw StateError('boom');
              }
            },
            builder: () => const Text('conteúdo'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(find.text('Não foi possível carregar esta seção.'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.text('conteúdo'), findsNothing);

      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.text('conteúdo'), findsOneWidget);
    },
  );
}
