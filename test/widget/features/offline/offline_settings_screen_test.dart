import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/offline/presentation/pages/offline_settings_screen.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_cache_status_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_coldigom_stats_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_maintenance_lock_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_reconcile_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedCacheStatusNotifier extends OfflineCacheStatusNotifier {
  _FixedCacheStatusNotifier(this.fixed);

  final OfflineCacheStatus fixed;
  var dismissCalls = 0;

  @override
  OfflineCacheStatus build() => fixed;

  @override
  Future<void> refreshAll() async {}

  @override
  Future<void> refresh({int? removedCount}) async {}

  @override
  void dismissRemovedWarning() => dismissCalls++;
}

class _LoggedOut extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

class _FixedSync extends ColdigomCatalogSyncNotifier {
  @override
  ColdigomCatalogSyncState build() =>
      const ColdigomCatalogSyncState(count: 2063);

  @override
  Future<ColdigomCatalogSyncResult> sync() async =>
      const ColdigomCatalogSyncNoop();
}

class _IdleReconcileNotifier extends OfflineReconcileNotifier {
  @override
  OfflineReconcileState build() => const OfflineReconcileState();

  @override
  Future<void> requestReconcile() async {}
}

class _BusyLock extends OfflineMaintenanceLock {
  @override
  OfflineMaintenanceOwner? build() => OfflineMaintenanceOwner.reconcile;
}

late SharedPreferences _prefs;

Future<_FixedCacheStatusNotifier> _pump(
  WidgetTester tester, {
  OfflineCacheStatus status = const OfflineCacheStatus(
    diskUsageBytes: 5 * 1024 * 1024,
  ),
  List<Override> extra = const [],
}) async {
  final cache = _FixedCacheStatusNotifier(status);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      retry: (retryCount, error) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_prefs),
        authStateProvider.overrideWith(_LoggedOut.new),
        offlineCacheStatusProvider.overrideWith(() => cache),
        offlineReconcileProvider.overrideWith(_IdleReconcileNotifier.new),
        coldigomCatalogSyncProvider.overrideWith(_FixedSync.new),
        offlineColdigomStatsProvider.overrideWith(
          (ref) async => OfflineColdigomStats.empty,
        ),
        ...extra,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: const OfflineSettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cache;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  testWidgets('uma secção «Baixar para usar offline» e um só «Atualizar»', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Baixar para usar offline'), findsOneWidget);
    expect(find.text('Acervo PLPCG (PDFs)'), findsNothing);
    expect(find.text('Coldigom por tipo de material'), findsNothing);
    expect(find.text('Atualizar'), findsOneWidget);
    expect(find.byType(FilterChip), findsNothing);
    expect(find.text('Limpar cache offline'), findsNothing);
  });

  testWidgets('banner de removidos só com «Dispensar»', (tester) async {
    final cache = await _pump(
      tester,
      status: const OfflineCacheStatus(removedCount: 2),
    );

    expect(
      find.text('2 PDFs deixaram de estar disponíveis localmente'),
      findsOneWidget,
    );
    final banner = find.byType(MaterialBanner);
    expect(
      find.descendant(of: banner, matching: find.byType(TextButton)),
      findsOneWidget,
    );
    await tester.tap(find.text('Dispensar'));
    expect(cache.dismissCalls, 1);
  });

  testWidgets('manutenção de outro dono desabilita «Dispensar»', (
    tester,
  ) async {
    await _pump(
      tester,
      status: const OfflineCacheStatus(removedCount: 1),
      extra: [offlineMaintenanceLockProvider.overrideWith(_BusyLock.new)],
    );

    final dismiss = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Dispensar'),
    );
    expect(dismiss.onPressed, isNull);
  });

  testWidgets('sem overflow a 400px de largura', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(
      tester,
      status: const OfflineCacheStatus(
        diskUsageBytes: 1 << 30,
        removedCount: 12,
        freeDiskBytes: 1 << 34,
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
