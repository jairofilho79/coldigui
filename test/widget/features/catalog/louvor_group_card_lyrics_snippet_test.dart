import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/widgets/louvor_group_card.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Louvor _louvorFixture(String pdfId) => Louvor(
  nome: 'Refúgio e Fortaleza',
  numero: '087',
  categoria: 'ColAdultos',
  classificacao: 'Partitura',
  pdf: 'ColAdultos/087.pdf',
  pdfId: pdfId,
  groupId: '087:refugio',
  searchTitleNorm: 'refugio e fortaleza',
  searchContentTokens: const [],
  searchCompactContent: '',
);

LouvorGroup _groupWith(ColdigomPraiseMetadata? meta, String pdfId) => LouvorGroup(
  groupId: '087:refugio',
  numero: '087',
  nome: 'Refúgio e Fortaleza',
  sections: [
    LouvorMaterialSection(
      classificacao: 'Partitura',
      displayLabel: 'Partitura',
      materials: [
        LouvorMaterialEntry(
          categoria: 'ColAdultos',
          pdfId: pdfId,
          louvor: _louvorFixture(pdfId),
        ),
      ],
    ),
  ],
).withColdigomMeta(meta);

Future<void> _pumpCard(WidgetTester tester, LouvorGroup group) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(body: LouvorGroupCard(group: group)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final pdfId = encodePdfId('ColAdultos/087.pdf');

  testWidgets('coldigomMeta com lyricsExcerpt chega até o chip', (tester) async {
    await _pumpCard(
      tester,
      _groupWith(
        const ColdigomPraiseMetadata(
          name: 'Refúgio e Fortaleza',
          lyricsExcerpt: '…caiam ao mar, eu não temerei, pois Tu…',
        ),
        pdfId,
      ),
    );

    expect(find.textContaining('não temerei'), findsOneWidget);
  });

  testWidgets('sem coldigomMeta, nenhum trecho aparece', (tester) async {
    await _pumpCard(tester, _groupWith(null, pdfId));

    expect(find.textContaining('não temerei'), findsNothing);
  });
}
