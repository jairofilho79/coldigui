import 'dart:async';

import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/library/domain/entities/library_catalog_mode.dart';
import 'package:coldigui/features/library/domain/entities/paginated_louvor_groups.dart';
import 'package:coldigui/features/library/presentation/pages/library_screen.dart';
import 'package:coldigui/features/library/presentation/providers/library_catalog_mode_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_coldigom_browse_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_group_results_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_group_worker.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

class _FakeCarouselNotifier extends CarouselLouvoresNotifier {
  @override
  List<CarouselItem> build() => const [];
}

/// Fixa o modo (PLPCG/Coldigom) sem hidratar por URL — evita depender do
/// [WidgetsBinding.addPostFrameCallback] de [LibraryScreen._hydrateFromUrl].
class _FixedLibraryCatalogModeNotifier extends LibraryCatalogModeNotifier {
  _FixedLibraryCatalogModeNotifier(this._mode);

  final LibraryCatalogMode _mode;

  @override
  LibraryCatalogMode build() => _mode;

  // `LibraryScreen._hydrateFromUrl` chama isto com `fonte: null` no
  // primeiro frame — sem o no-op, ele reverte para `plpcg` (default de
  // `LibraryCatalogMode.fromUrl`) e desfaz o override.
  @override
  void hydrateFromUrl({String? fonte}) {}
}

/// Sempre falha — `StateError` evita o auto-retry padrão do Riverpod 3
/// (mesmo cuidado do `_ErrorLouvoresManifestNotifier`, ver
/// `louvores_manifest_test_helpers.dart`).
class _ErrorLibraryColdigomBrowseNotifier
    extends LibraryColdigomBrowseNotifier {
  _ErrorLibraryColdigomBrowseNotifier(this._onBuild);

  final void Function()? _onBuild;

  @override
  Future<PaginatedLouvorGroups> build() async {
    _onBuild?.call();
    throw StateError('coldigom indisponível (teste)');
  }
}

Widget _libraryErrorTestApp({
  required SharedPreferences prefs,
  required List<Override> extraOverrides,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      carouselLouvoresProvider.overrideWith(_FakeCarouselNotifier.new),
      libraryGroupPipelineExecutorProvider.overrideWith(
        (ref) =>
            (input) async => runLibraryGroupPipeline(input),
      ),
      ...extraOverrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: const Scaffold(body: LibraryScreen()),
    ),
  );
}

/// `pumpAndSettle` trava com o shimmer do skeleton (animação em loop).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'LibraryScreen (PLPCG) em erro mostra "Tentar novamente" que invalida o manifest',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      var buildCount = 0;

      await tester.pumpWidget(
        _libraryErrorTestApp(
          prefs: prefs,
          extraOverrides: [
            louvoresManifestErrorOverride(onBuild: () => buildCount++),
            connectivityStreamProvider.overrideWith(
              (ref) => const Stream<bool>.empty(),
            ),
          ],
        ),
      );
      await _settle(tester);

      expect(buildCount, 1);
      expect(find.text('Não foi possível carregar o catálogo'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Tentar novamente'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Tentar novamente'));
      await _settle(tester);

      expect(buildCount, 2);
    },
  );

  testWidgets(
    'LibraryScreen (Coldigom) em erro mostra "Tentar novamente" que invalida o browse',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      var buildCount = 0;

      await tester.pumpWidget(
        _libraryErrorTestApp(
          prefs: prefs,
          extraOverrides: [
            libraryCatalogModeProvider.overrideWith(
              () =>
                  _FixedLibraryCatalogModeNotifier(LibraryCatalogMode.coldigom),
            ),
            libraryColdigomBrowseProvider.overrideWith(
              () => _ErrorLibraryColdigomBrowseNotifier(() => buildCount++),
            ),
            connectivityStreamProvider.overrideWith(
              (ref) => const Stream<bool>.empty(),
            ),
          ],
        ),
      );
      await _settle(tester);

      expect(buildCount, 1);
      expect(
        find.text('Não foi possível carregar o catálogo Coldigom'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Tentar novamente'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Tentar novamente'));
      await _settle(tester);

      expect(buildCount, 2);
    },
  );

  testWidgets(
    'LibraryScreen recarrega automaticamente quando a conectividade volta',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      var buildCount = 0;
      final connectivityController = StreamController<bool>();
      addTearDown(connectivityController.close);

      await tester.pumpWidget(
        _libraryErrorTestApp(
          prefs: prefs,
          extraOverrides: [
            louvoresManifestErrorOverride(onBuild: () => buildCount++),
            connectivityStreamProvider.overrideWith(
              (ref) => connectivityController.stream,
            ),
          ],
        ),
      );
      await _settle(tester);

      expect(buildCount, 1);

      connectivityController.add(true);
      await _settle(tester);

      expect(buildCount, 2);
    },
  );
}
