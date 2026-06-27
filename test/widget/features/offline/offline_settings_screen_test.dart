import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/offline/domain/entities/offline_download_progress.dart';
import 'package:coldigui/features/offline/domain/entities/offline_stats.dart';
import 'package:coldigui/features/offline/presentation/pages/offline_settings_screen.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_bulk_download_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_cache_status_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_category_selection_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_missing_louvores_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_missing_download_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_mode_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_reconcile_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedCacheStatusNotifier extends OfflineCacheStatusNotifier {
  _FixedCacheStatusNotifier(this.fixed);

  final OfflineCacheStatus fixed;

  @override
  OfflineCacheStatus build() => fixed;
}

class _IdleReconcileNotifier extends OfflineReconcileNotifier {
  @override
  OfflineReconcileState build() => const OfflineReconcileState();

  @override
  Future<void> requestReconcile() async {}
}

class _IdleBulkNotifier extends OfflineBulkDownloadNotifier {
  @override
  OfflineBulkDownloadState build() => const OfflineBulkDownloadState();
}

class _RunningBulkWithFetchProgressNotifier
    extends OfflineBulkDownloadNotifier {
  @override
  OfflineBulkDownloadState build() => OfflineBulkDownloadState(
        status: OfflineBulkDownloadStatus.running,
        progress: OfflineDownloadProgress(
          phase: OfflineDownloadPhase.fetching,
          currentCategory: 'Partitura',
          categoryIndex: 0,
          totalCategories: 1,
          currentPart: 1,
          totalParts: 3,
          donePdfs: 0,
          totalPdfs: 100,
          zipBytesReceived: 45 * 1024 * 1024,
          zipBytesTotal: 82 * 1024 * 1024,
        ),
      );
}

class _IdleMissingNotifier extends OfflineMissingDownloadNotifier {
  @override
  OfflineMissingDownloadState build() => const OfflineMissingDownloadState();
}

class _FixedOfflineModeNotifier extends OfflineModeNotifier {
  _FixedOfflineModeNotifier(this.configured);

  final bool configured;

  @override
  bool build() => configured;
}

class _FixedCategorySelectionNotifier extends OfflineCategorySelectionNotifier {
  _FixedCategorySelectionNotifier(this.fixed);

  final OfflineCategorySelectionState fixed;

  @override
  OfflineCategorySelectionState build() => fixed;
}

Widget _offlineTestApp({
  required OfflineCacheStatus cacheStatus,
  bool maintenanceMode = true,
  OfflineCategorySelectionState selectionState =
      const OfflineCategorySelectionState(
    selected: CatalogMaterials.defaultSelected,
    bulkDownloaded: {CatalogMaterials.partitura},
  ),
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      offlineCacheStatusProvider.overrideWith(
        () => _FixedCacheStatusNotifier(cacheStatus),
      ),
      offlineModeProvider.overrideWith(
        () => _FixedOfflineModeNotifier(maintenanceMode),
      ),
      offlineCategorySelectionProvider.overrideWith(
        () => _FixedCategorySelectionNotifier(selectionState),
      ),
      offlineReconcileProvider.overrideWith(_IdleReconcileNotifier.new),
      offlineBulkDownloadProvider.overrideWith(_IdleBulkNotifier.new),
      offlineMissingDownloadProvider.overrideWith(_IdleMissingNotifier.new),
      ...extraOverrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pt'),
      home: const OfflineSettingsScreen(),
    ),
  );
}

void main() {
  testWidgets('shows stats section and clear cache button', (tester) async {
    await tester.pumpWidget(
      _offlineTestApp(
        cacheStatus: const OfflineCacheStatus(
          stats: OfflineStats(byCategory: {'Partitura': 3}),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('PDFs armazenados'), findsOneWidget);
    expect(find.text('3 PDFs offline'), findsOneWidget);
    expect(find.text('Atualizar'), findsWidgets);
    expect(find.text('Limpar cache offline'), findsOneWidget);
    expect(find.text('Baixar faltantes'), findsWidgets);
    expect(find.text('Baixar selecionados'), findsOneWidget);
    expect(find.byType(FilterChip), findsWidgets);
  });

  testWidgets('shows bulk setup when maintenance mode is off', (tester) async {
    await tester.pumpWidget(
      _offlineTestApp(
        cacheStatus: const OfflineCacheStatus(
          stats: OfflineStats(byCategory: {}),
        ),
        maintenanceMode: false,
      ),
    );
    await tester.pump();

    expect(find.text('Selecione as categorias'), findsOneWidget);
    expect(find.text('Baixar selecionados'), findsOneWidget);
    expect(find.text('PDFs armazenados'), findsNothing);
    expect(find.text('Baixar faltantes'), findsNothing);
  });

  testWidgets('shows removed banner when removedCount > 0', (tester) async {
    await tester.pumpWidget(
      _offlineTestApp(
        cacheStatus: const OfflineCacheStatus(
          stats: OfflineStats(byCategory: {'Partitura': 1}),
          removedCount: 2,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('2 PDFs deixaram de estar disponíveis localmente'),
      findsOneWidget,
    );
    expect(find.text('Dispensar'), findsOneWidget);
  });

  testWidgets('shows unreliable missing label when manifest unavailable',
      (tester) async {
    await tester.pumpWidget(
      _offlineTestApp(
        cacheStatus: const OfflineCacheStatus(
          stats: OfflineStats(
            byCategory: {'Partitura': 2},
            missingCountReliable: false,
          ),
        ),
        selectionState: const OfflineCategorySelectionState(
          selected: {CatalogMaterials.partitura},
          bulkDownloaded: {CatalogMaterials.partitura},
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Faltantes indisponíveis (sem conexão)'),
      findsOneWidget,
    );
    expect(
      find.text('Partitura: 2 (— faltantes, sem conexão)'),
      findsOneWidget,
    );
  });

  testWidgets('enables Baixar selecionados for new category in maintenance',
      (tester) async {
    await tester.pumpWidget(
      _offlineTestApp(
        cacheStatus: const OfflineCacheStatus(
          stats: OfflineStats(byCategory: {'Partitura': 3}),
        ),
        selectionState: const OfflineCategorySelectionState(
          selected: {
            CatalogMaterials.partitura,
            CatalogMaterials.gestosEmGravura,
          },
          bulkDownloaded: {CatalogMaterials.partitura},
        ),
      ),
    );
    await tester.pump();

    final downloadSelected =
        find.widgetWithText(FilledButton, 'Baixar selecionados');
    expect(downloadSelected, findsOneWidget);
    expect(
      tester.widget<FilledButton>(downloadSelected).onPressed,
      isNotNull,
    );
  });

  testWidgets('long press on bulk category chip opens missing louvores sheet',
      (tester) async {
    const missingLouvor = Louvor(
      nome: 'Bondade de Deus',
      numero: '002',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: 'bondade.pdf',
      pdfId: 'missing-part',
      groupId: 'missing-part',
      searchTitleNorm: 'bondade de deus',
      searchContentTokens: [],
      searchCompactContent: '',
    );

    await tester.pumpWidget(
      _offlineTestApp(
        cacheStatus: const OfflineCacheStatus(
          stats: OfflineStats(
            byCategory: {'Partitura': 1},
            missingByCategory: {'Partitura': 1},
          ),
        ),
        selectionState: const OfflineCategorySelectionState(
          selected: {CatalogMaterials.partitura},
          bulkDownloaded: {CatalogMaterials.partitura},
        ),
        extraOverrides: [
          offlineMissingLouvoresProvider(CatalogMaterials.partitura)
              .overrideWith((ref) async => [missingLouvor]),
        ],
      ),
    );
    await tester.pump();

    await tester.longPress(find.textContaining('Partitura: 1'));
    await tester.pumpAndSettle();

    expect(find.text('Partitura — faltantes'), findsOneWidget);
    expect(find.text('#002 — Bondade de Deus'), findsOneWidget);
  });

  testWidgets('disables clear cache when selected categories have no PDFs',
      (tester) async {
    await tester.pumpWidget(
      _offlineTestApp(
        cacheStatus: const OfflineCacheStatus(
          stats: OfflineStats(byCategory: {'Partitura': 3}),
        ),
        selectionState: const OfflineCategorySelectionState(
          selected: {CatalogMaterials.gestosEmGravura},
          bulkDownloaded: {CatalogMaterials.partitura},
        ),
      ),
    );
    await tester.pump();

    final clearButton = find.widgetWithText(TextButton, 'Limpar cache offline');
    expect(clearButton, findsOneWidget);
    expect(tester.widget<TextButton>(clearButton).onPressed, isNull);
  });

  testWidgets('enables clear cache when selected category has PDFs',
      (tester) async {
    await tester.pumpWidget(
      _offlineTestApp(
        cacheStatus: const OfflineCacheStatus(
          stats: OfflineStats(byCategory: {'Partitura': 3}),
        ),
        selectionState: const OfflineCategorySelectionState(
          selected: {CatalogMaterials.partitura},
          bulkDownloaded: {CatalogMaterials.partitura},
        ),
      ),
    );
    await tester.pump();

    final clearButton = find.widgetWithText(TextButton, 'Limpar cache offline');
    expect(clearButton, findsOneWidget);
    expect(tester.widget<TextButton>(clearButton).onPressed, isNotNull);
  });

  testWidgets('shows zip byte progress during fetching phase', (tester) async {
    await tester.pumpWidget(
      _offlineTestApp(
        cacheStatus: const OfflineCacheStatus(
          stats: OfflineStats(byCategory: {}),
        ),
        maintenanceMode: false,
        extraOverrides: [
          offlineBulkDownloadProvider.overrideWith(
            _RunningBulkWithFetchProgressNotifier.new,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    expect(find.textContaining('0/100 PDFs'), findsOneWidget);
    expect(find.textContaining('Baixando pacote 1/3'), findsOneWidget);
    expect(find.textContaining('45,0 MB'), findsOneWidget);
    expect(find.textContaining('82,0 MB'), findsOneWidget);
  });
}
