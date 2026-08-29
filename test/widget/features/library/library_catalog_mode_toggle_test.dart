import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/catalog/presentation/widgets/category_filters.dart';
import 'package:coldigui/features/catalog/presentation/widgets/filters_panel.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:coldigui/features/library/domain/entities/library_catalog_mode.dart';
import 'package:coldigui/features/library/presentation/providers/coldigom_library_facets_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_catalog_mode_provider.dart';
import 'package:coldigui/features/library/presentation/widgets/coldigom_library_filters.dart';
import 'package:coldigui/features/library/presentation/widgets/library_catalog_mode_toggle.dart';
import 'package:coldigui/features/library/presentation/widgets/special_arrangement_filters.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('modo coldigom usa filtros Coldigom em vez de PLPCG', (
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
          home: Consumer(
            builder: (context, ref, _) {
              final mode = ref.watch(libraryCatalogModeProvider);
              final isColdigom = mode == LibraryCatalogMode.coldigom;
              return Scaffold(
                backgroundColor: AppColors.background,
                body: ListView(
                  children: [
                    const LibraryCatalogModeToggle(),
                    FiltersPanel(
                      initiallyExpanded: true,
                      showPlpcgSections: !isColdigom,
                      additionalExpandedSections: [
                        if (isColdigom)
                          const ColdigomLibraryFilters()
                        else
                          const SpecialArrangementFilters(),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(CategoryFilters), findsOneWidget);
    expect(find.byType(ColdigomLibraryFilters), findsNothing);

    await tester.tap(find.text('Coldigom'));
    await tester.pumpAndSettle();

    expect(find.byType(ColdigomLibraryFilters), findsOneWidget);
    expect(find.byType(CategoryFilters), findsNothing);
    expect(find.text('Tom'), findsOneWidget);
    expect(find.text('Dm'), findsOneWidget);
  });
}
