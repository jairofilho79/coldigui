import 'package:coldigui/features/catalog/presentation/widgets/coldigom_meta_block.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ColdigomMetaBlock exibe iluminacao biblica discreta em uma linha', (
    tester,
  ) async {
    const meta = ColdigomPraiseMetadata(
      name: 'Salmo 23',
      tonality: 'D',
      rhythm: 'Lento',
      author: 'Davi',
      biblicalSummary: 'Sl 23:1 — O Senhor é meu pastor',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(
          body: Builder(
            builder: (context) => ColdigomMetaBlock(
              l10n: AppLocalizations.of(context)!,
              meta: meta,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Iluminação Bíblica'), findsOneWidget);
    final textFinder = find.text('Sl 23:1 — O Senhor é meu pastor');
    expect(textFinder, findsOneWidget);

    final Text textWidget = tester.widget(textFinder);
    expect(textWidget.maxLines, 1);
    expect(textWidget.overflow, TextOverflow.ellipsis);
  });
}
