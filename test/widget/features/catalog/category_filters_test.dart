import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/catalog/presentation/widgets/category_filters.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CategoryFilters desmarca material ao toque', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final selected = ref
                    .watch(catalogFiltersProvider)
                    .selectedMaterials;
                return Column(
                  children: [
                    Text('count=${selected.length}'),
                    const CategoryFilters(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('count=${CatalogMaterials.defaultSelected.length}'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Partitura'));
    await tester.pumpAndSettle();

    expect(
      find.text('count=${CatalogMaterials.defaultSelected.length - 1}'),
      findsOneWidget,
    );
  });
}
