import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/presentation/pages/home_screen.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Louvor _louvor({
  required String nome,
  required String categoria,
  String classificacao = 'ColAdultos',
  String numero = '1',
}) =>
    Louvor.fromManifest(
      nome: nome,
      numero: numero,
      categoria: categoria,
      classificacao: classificacao,
      pdf: '$numero.pdf',
      pdfId: 'id-$numero',
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('CategoryFilters oculta louvor ao desmarcar material',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final catalog = [
      _louvor(
        nome: 'Partitura Louvor',
        categoria: CatalogMaterials.partitura,
        numero: '001',
      ),
      _louvor(
        nome: 'Gestos Louvor',
        categoria: CatalogMaterials.gestosEmGravura,
        numero: '002',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          louvoresManifestProvider.overrideWith((ref) async => catalog),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '001');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Partitura Louvor'), findsOneWidget);

    await tester.tap(find.text('Toque para ver mais'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Partitura'));
    await tester.pumpAndSettle();

    expect(find.text('Partitura Louvor'), findsNothing);
  });
}
