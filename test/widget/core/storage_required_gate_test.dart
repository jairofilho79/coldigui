import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/widgets/degraded_storage_banner.dart';
import 'package:coldigui/core/widgets/storage_required_gate.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes/fake_isar.dart';

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

  testWidgets('opening mostra a logo pulsante de preparação, não o erro', (
    tester,
  ) async {
    await pumpGate(tester, IsarStatus.opening);

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
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

  for (final retryInBanner in [true, false]) {
    testWidgets(
      'retry pelo ${retryInBanner ? 'banner' : 'gate'} recupera o banco e libera a área',
      (tester) async {
        var attempts = 0;
        final isar = FakeIsar();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              isarOpenerProvider.overrideWithValue(() async {
                if (++attempts == 1) throw StateError('core indisponível');
                return isar;
              }),
            ],
            child: MaterialApp(
              locale: const Locale('pt'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Column(
                children: [
                  DegradedStorageBanner(),
                  Expanded(child: StorageRequiredGate(child: Text('conteúdo'))),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.storageUnavailableTitle), findsOneWidget);
        expect(find.text('conteúdo'), findsNothing);

        final retry = retryInBanner
            ? find.widgetWithText(TextButton, l10n.retry)
            : find.widgetWithText(FilledButton, l10n.retry);
        await tester.tap(retry);
        await tester.pumpAndSettle();

        expect(find.text('conteúdo'), findsOneWidget);
        expect(find.text(l10n.storageUnavailableTitle), findsNothing);
        expect(find.text(l10n.degradedStorageBannerMessage), findsNothing);
        expect(attempts, 2);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(isar.closeCallCount, 1);
      },
    );
  }
}
