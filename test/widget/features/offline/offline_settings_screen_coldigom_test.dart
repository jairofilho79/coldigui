import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/auth/presentation/widgets/google_sign_in_button.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import 'package:coldigui/features/offline/domain/entities/coldigom_download_progress.dart';
import 'package:coldigui/features/offline/domain/exceptions/offline_bulk_exceptions.dart';
import 'package:coldigui/features/offline/presentation/pages/offline_settings_widgets/coldigom_section.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_coldigom_download_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_coldigom_stats_provider.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_maintenance_lock_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/pump_app.dart';

class _LoggedIn extends AuthNotifier {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(googleSub: 's', sessionToken: 't');
}

class _LoggedOut extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

class _FixedSync extends ColdigomCatalogSyncNotifier {
  _FixedSync(this.fixed);
  final ColdigomCatalogSyncState fixed;
  @override
  ColdigomCatalogSyncState build() => fixed;
  var syncCalls = 0;
  @override
  Future<ColdigomCatalogSyncResult> sync() async {
    syncCalls++;
    return const ColdigomCatalogSyncNoop();
  }
}

class _FixedDownload extends OfflineColdigomDownloadNotifier {
  _FixedDownload(this.fixed);
  final OfflineColdigomDownloadState fixed;
  final started = <Set<String>>[];
  var stops = 0;
  var removes = 0;
  @override
  OfflineColdigomDownloadState build() => fixed;
  @override
  Future<void> start(Set<String> kindIds) async => started.add(kindIds);
  @override
  void stop() => stops++;
  @override
  Future<RemoveColdigomDownloadsResult?> removeDownloads() async {
    removes++;
    return const RemoveColdigomDownloadsResult(
      removedPdfs: 1,
      removedAudios: 2,
    );
  }
}

class _BusyLock extends OfflineMaintenanceLock {
  @override
  OfflineMaintenanceOwner? build() => OfflineMaintenanceOwner.bulk;
}

const _stats = OfflineColdigomStats({
  'k-grade': ColdigomKindStats(
    kindId: 'k-grade',
    kindName: 'Grade',
    total: 10,
    downloaded: 4,
    bytesKnown: 0,
    bytesEstimated: 10 * 350 * 1024,
    pendingBytes: 6 * 350 * 1024,
  ),
  'k-play': ColdigomKindStats(
    kindId: 'k-play',
    kindName: 'Playback',
    total: 5,
    downloaded: 0,
    bytesKnown: 0,
    bytesEstimated: 5 * 4 * 1024 * 1024,
    pendingBytes: 5 * 4 * 1024 * 1024,
  ),
  'k-cifra': ColdigomKindStats(
    kindId: 'k-cifra',
    kindName: 'Cifra',
    total: 3,
    downloaded: 3,
    bytesKnown: 0,
    bytesEstimated: 3 * 1024,
    pendingBytes: 0,
  ),
});

late SharedPreferences _prefs;

Future<({_FixedSync sync, _FixedDownload download})> _pump(
  WidgetTester tester, {
  bool loggedIn = true,
  ColdigomCatalogSyncState syncState = const ColdigomCatalogSyncState(
    count: 1690,
  ),
  OfflineColdigomDownloadState downloadState =
      const OfflineColdigomDownloadState(),
  Map<String, int> rank = const {'k-grade': 0, 'k-play': 1},
  List<Override> extra = const [],
}) async {
  final sync = _FixedSync(syncState);
  final download = _FixedDownload(downloadState);
  await pumpApp(
    tester,
    const SingleChildScrollView(
      child: ColdigomOfflineSection(maintenanceBusy: false),
    ),
    overrides: [
      sharedPreferencesProvider.overrideWithValue(_prefs),
      authStateProvider.overrideWith(loggedIn ? _LoggedIn.new : _LoggedOut.new),
      favoriteMaterialKindRankProvider.overrideWithValue(rank),
      offlineColdigomStatsProvider.overrideWith((ref) async => _stats),
      coldigomCatalogSyncProvider.overrideWith(() => sync),
      offlineColdigomDownloadProvider.overrideWith(() => download),
      ...extra,
    ],
  );
  await tester.pumpAndSettle();
  return (sync: sync, download: download);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  testWidgets('deslogado: convite + botão Google; sem lista de kinds', (
    tester,
  ) async {
    await _pump(tester, loggedIn: false);

    expect(
      find.text('Entre com Google para baixar os seus tipos favoritos'),
      findsOneWidget,
    );
    expect(find.byType(GoogleSignInButton), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
  });

  testWidgets(
    'linha do catálogo com contagem e botão Atualizar; sem catálogo mostra o aviso',
    (tester) async {
      final handles = await _pump(tester);
      expect(find.textContaining('Catálogo: 1690 louvores'), findsOneWidget);
      await tester.tap(find.text('Atualizar'));
      await tester.pumpAndSettle();
      expect(handles.sync.syncCalls, 1);

      await _pump(tester, syncState: const ColdigomCatalogSyncState(count: 0));
      expect(
        find.text('Ligue-se à internet para baixar o catálogo'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'logado: favoritos pré-marcados na ordem do rank, «Outros tipos» fechado',
    (tester) async {
      await _pump(tester);

      final tiles = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .toList();
      expect(tiles.map((t) => (t.title as Text).data), ['Grade', 'Playback']);
      expect(tiles.every((t) => t.value == true), isTrue);
      expect(find.text('Outros tipos'), findsOneWidget);
      expect(find.text('Cifra'), findsNothing);
      expect(find.textContaining('10 materiais · ~'), findsOneWidget);
      expect(find.textContaining('Baixar selecionados (~'), findsOneWidget);

      await tester.tap(find.text('Outros tipos'));
      await tester.pumpAndSettle();
      expect(find.text('Cifra'), findsOneWidget);
    },
  );

  testWidgets(
    'desmarcar grava a decisão local (O11) e o botão inicia só com os marcados',
    (tester) async {
      final handles = await _pump(tester);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Playback'));
      await tester.pumpAndSettle();
      expect(_prefs.getString('offlineColdigomKindIds'), '["k-grade"]');

      await tester.tap(find.textContaining('Baixar selecionados'));
      await tester.pumpAndSettle();
      expect(handles.download.started.single, {'k-grade'});
    },
  );

  testWidgets('lock ocupado por outro dono desabilita os botões', (
    tester,
  ) async {
    await _pump(
      tester,
      extra: [offlineMaintenanceLockProvider.overrideWith(_BusyLock.new)],
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(find.textContaining('Baixar selecionados (~'), findsOneWidget);
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'emissão inicial (kindId vazio) mostra só a barra, sem " · 0/0"',
    (tester) async {
      await _pump(
        tester,
        downloadState: const OfflineColdigomDownloadState(
          status: OfflineColdigomDownloadStatus.running,
          progress: ColdigomDownloadProgress(
            kindId: '',
            doneInKind: 0,
            totalInKind: 0,
            doneTotal: 0,
            total: 1690,
            currentTitle: '',
          ),
        ),
      );

      expect(find.textContaining('· 0/0'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    },
  );

  testWidgets('removendo desabilita Baixar, Tentar de novo e Remover', (
    tester,
  ) async {
    await _pump(
      tester,
      downloadState: OfflineColdigomDownloadState(
        removing: true,
        result: ColdigomDownloadResult(
          done: 0,
          skipped: 0,
          bytes: 0,
          failed: [
            ColdigomDownloadFailure(materialId: 'x', cause: StateError('x')),
          ],
        ),
      ),
    );

    final download = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(download.onPressed, isNull);
    final retry = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Tentar de novo'),
    );
    expect(retry.onPressed, isNull);
    final remove = tester.widget<TextButton>(
      find.widgetWithText(
        TextButton,
        'Remover áudios e PDFs baixados do Coldigom',
      ),
    );
    expect(remove.onPressed, isNull);
  });

  testWidgets(
    'em execução mostra progresso e Parar; concluído com falhas mostra Tentar de novo',
    (tester) async {
      final running = await _pump(
        tester,
        downloadState: const OfflineColdigomDownloadState(
          status: OfflineColdigomDownloadStatus.running,
          progress: ColdigomDownloadProgress(
            kindId: 'k-grade',
            doneInKind: 3,
            totalInKind: 10,
            doneTotal: 120,
            total: 1690,
            currentTitle: '001 · x',
          ),
        ),
      );
      expect(find.text('Grade · 3/10'), findsOneWidget);
      await tester.tap(find.text('Parar'));
      expect(running.download.stops, 1);

      // Cancelando (O12): «Parar» vira «Parando...» e some o botão «Parar».
      await _pump(
        tester,
        downloadState: const OfflineColdigomDownloadState(
          status: OfflineColdigomDownloadStatus.cancelling,
        ),
      );
      expect(find.text('Parando...'), findsOneWidget);
      expect(find.text('Parar'), findsNothing);

      final done = await _pump(
        tester,
        downloadState: OfflineColdigomDownloadState(
          status: OfflineColdigomDownloadStatus.done,
          result: ColdigomDownloadResult(
            done: 8,
            skipped: 2,
            bytes: 1,
            failed: [
              ColdigomDownloadFailure(materialId: 'x', cause: StateError('x')),
            ],
          ),
        ),
      );
      expect(find.text('1 não baixado'), findsOneWidget);
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();
      expect(done.download.started, hasLength(1));
    },
  );

  testWidgets(
    'parado (cancelamento) mostra "Parado — N restantes" e Tentar de novo; '
    'nunca "Nada novo para baixar" (achado do review final)',
    (tester) async {
      await _pump(
        tester,
        downloadState: OfflineColdigomDownloadState(
          status: OfflineColdigomDownloadStatus.done,
          progress: const ColdigomDownloadProgress(
            kindId: 'k-grade',
            doneInKind: 3,
            totalInKind: 10,
            doneTotal: 120,
            total: 1690,
            currentTitle: '001 · x',
          ),
          result: const ColdigomDownloadResult(
            done: 3,
            skipped: 2,
            bytes: 1,
            failed: [],
            cancelled: true,
          ),
        ),
      );

      expect(find.text('Parado — 1570 restantes'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
      expect(find.textContaining('Nada novo para baixar'), findsNothing);
      expect(find.textContaining('não baixado'), findsNothing);
    },
  );

  testWidgets(
    'falta de espaço mostra "Sem espaço no aparelho", não "N não baixado"',
    (tester) async {
      await _pump(
        tester,
        downloadState: OfflineColdigomDownloadState(
          status: OfflineColdigomDownloadStatus.done,
          progress: const ColdigomDownloadProgress(
            kindId: 'k-grade',
            doneInKind: 3,
            totalInKind: 10,
            doneTotal: 120,
            total: 1690,
            currentTitle: '001 · x',
          ),
          result: const ColdigomDownloadResult(
            done: 0,
            skipped: 0,
            bytes: 0,
            failed: [
              ColdigomDownloadFailure(
                materialId: 'x',
                cause: InsufficientDiskSpaceException(
                  requiredBytes: 1,
                  availableBytes: 0,
                ),
              ),
            ],
            cancelled: true,
          ),
        ),
      );

      expect(find.text('Sem espaço no aparelho'), findsOneWidget);
      expect(find.textContaining('não baixado'), findsNothing);
      expect(find.textContaining('restantes'), findsNothing);
    },
  );

  testWidgets('remover pede confirmação e mostra o resultado', (tester) async {
    final handles = await _pump(tester);

    await tester.tap(find.text('Remover áudios e PDFs baixados do Coldigom'));
    await tester.pumpAndSettle();
    expect(find.text('Remover baixados do Coldigom?'), findsOneWidget);
    expect(
      find.text('Cifras, gestos e letras ficam no aparelho.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(handles.download.removes, 1);
    expect(find.text('1 PDFs e 2 áudios removidos'), findsOneWidget);
  });

  testWidgets(
    'sem overflow a 400px de largura (favoritos + progresso + falhas)',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(
        tester,
        downloadState: OfflineColdigomDownloadState(
          status: OfflineColdigomDownloadStatus.done,
          progress: const ColdigomDownloadProgress(
            kindId: 'k-grade',
            doneInKind: 3,
            totalInKind: 10,
            doneTotal: 120,
            total: 1690,
            currentTitle: '001 · x',
          ),
          result: ColdigomDownloadResult(
            done: 8,
            skipped: 2,
            bytes: 1,
            failed: [
              ColdigomDownloadFailure(materialId: 'x', cause: StateError('x')),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Outros tipos'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
