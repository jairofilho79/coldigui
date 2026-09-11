import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/widgets/storage_required_gate.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  Future<void> pumpGate(WidgetTester tester, IsarStatus status) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isarStatusProvider.overrideWithValue(status)],
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StorageRequiredGate(child: Text('conteúdo')),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('opening mostra spinner de preparação, não o erro', (
    tester,
  ) async {
    await pumpGate(tester, IsarStatus.opening);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(l10n.storagePreparing), findsOneWidget);
    expect(find.text(l10n.storageUnavailableTitle), findsNothing);
    expect(find.text('conteúdo'), findsNothing);
  });

  testWidgets('unavailable mostra o aviso traduzido com retry', (tester) async {
    await pumpGate(tester, IsarStatus.unavailable);

    expect(find.text(l10n.storageUnavailableTitle), findsOneWidget);
    expect(find.text(l10n.storageUnavailableBody), findsOneWidget);
    expect(find.text(l10n.retry), findsOneWidget);
    expect(find.text('conteúdo'), findsNothing);
  });

  testWidgets('available libera o child', (tester) async {
    await pumpGate(tester, IsarStatus.available);

    expect(find.text('conteúdo'), findsOneWidget);
  });
}
