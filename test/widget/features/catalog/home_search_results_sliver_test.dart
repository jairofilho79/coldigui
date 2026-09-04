import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/home_search_results_sliver.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Driver falso — não registra os `ref.listen` reais (evita depender do
/// manifest/coldigom de verdade), só conta chamadas a [retry].
class _FakeDriver extends HomeSearchPipelineDriver {
  var retryCalls = 0;

  @override
  int build() => 0;

  @override
  void retry() => retryCalls++;
}

Widget _sliverTestApp(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: const Scaffold(
        body: CustomScrollView(slivers: [HomeSearchResultsSliver()]),
      ),
    ),
  );
}

void main() {
  testWidgets('mostra linha de erro coldigom e re-dispara a busca ao tocar', (
    tester,
  ) async {
    final fakeDriver = _FakeDriver();

    await tester.pumpWidget(
      _sliverTestApp([
        homeSearchPipelineDriverProvider.overrideWith(() => fakeDriver),
        homeSearchColdigomErrorProvider.overrideWith((ref) => true),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coldigom indisponível · tentar de novo'), findsOneWidget);

    await tester.tap(find.text('Coldigom indisponível · tentar de novo'));
    await tester.pump();

    expect(fakeDriver.retryCalls, 1);
  });

  testWidgets('não mostra linha de erro quando a flag está em false', (
    tester,
  ) async {
    final fakeDriver = _FakeDriver();

    await tester.pumpWidget(
      _sliverTestApp([
        homeSearchPipelineDriverProvider.overrideWith(() => fakeDriver),
        homeSearchColdigomErrorProvider.overrideWith((ref) => false),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coldigom indisponível · tentar de novo'), findsNothing);
  });
}
