import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/catalog/presentation/widgets/category_filters.dart';
import 'package:coldigui/features/catalog/presentation/widgets/filters_panel.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:coldigui/features/library/presentation/providers/coldigom_library_facets_provider.dart';
import 'package:coldigui/features/library/presentation/widgets/coldigom_library_filters.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('biblioteca só Coldigom mostra filtros Coldigom sem PLPCG', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coldigomLibraryFacetsProvider.overrideWith(
            (ref) async => const ColdigomLibraryFacets(
              options: ColdigomFilterOptionsDto(
                rhythms: ['Fox'],
                tonalities: ['Dm'],
                categories: ['Clamor'],
                tags: [ColdigomTagFacetDto(id: 't1', name: 'PES', count: 1)],
              ),
              materialKinds: [
                ColdigomMaterialKindDto(id: 'k1', name: 'Partitura'),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            backgroundColor: AppColors.background,
            body: ListView(
              children: [
                FiltersPanel(
                  initiallyExpanded: true,
                  showPlpcgSections: false,
                  additionalExpandedSections: const [ColdigomLibraryFilters()],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ColdigomLibraryFilters), findsOneWidget);
    expect(find.byType(CategoryFilters), findsNothing);
    expect(find.text('Tom'), findsOneWidget);
    expect(find.text('Dm'), findsOneWidget);
  });
}
