import 'package:coldigui/features/offline/domain/entities/offline_stats.dart';
import 'package:coldigui/features/offline/presentation/pages/offline_settings_screen.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_bulk_download_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_cache_status_provider.dart';
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

Widget _offlineTestApp({
  required OfflineCacheStatus cacheStatus,
  bool maintenanceMode = true,
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
}
