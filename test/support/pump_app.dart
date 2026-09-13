// test/support/pump_app.dart
//
// Casca padrão de teste de widget (E10): `ProviderScope` + `MaterialApp` com
// a l10n real do app + `Scaffold(body: child)`, para não repetir esse boiler
// plate em cada arquivo (ver `test_overrides.dart` para os overrides de
// provider que costumam acompanhar este pump).
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta [child] dentro de `ProviderScope(overrides) > MaterialApp (com
/// l10n) > Scaffold(body:)` e faz o primeiro pump.
///
/// Não chama `pumpAndSettle` — testes que dependem de animações/timers
/// terminando continuam chamando isso explicitamente depois.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  Locale locale = const Locale('pt'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
}
