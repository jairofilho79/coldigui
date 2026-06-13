import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/catalog/presentation/pages/home_screen.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/home_search_worker.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCarouselNotifier extends CarouselLouvoresNotifier {
  @override
  List<CarouselItem> build() => const [];
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HomeScreen exibe hint de busca localizado em pt',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          louvoresManifestProvider.overrideWith(
            (ref) async => LouvoresManifest.fromLouvores(const []),
          ),
          carouselLouvoresProvider.overrideWith(_FakeCarouselNotifier.new),
          homeSearchPipelineExecutorProvider.overrideWith(
            (ref) => (input) async => runHomeSearchPipeline(input),
          ),
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

    expect(find.text('Buscar por número ou título'), findsOneWidget);
    expect(find.text('Filtros'), findsOneWidget);
    expect(find.text('Toque para ver mais'), findsOneWidget);
  });
}
