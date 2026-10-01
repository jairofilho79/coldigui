import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/auth/presentation/widgets/google_sign_in_button.dart';
import 'package:coldigui/features/catalog/domain/entities/material_kind_taxonomy.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';
import 'package:coldigui/features/offline/domain/entities/coldigom_download_progress.dart';
import 'package:coldigui/features/offline/domain/exceptions/offline_bulk_exceptions.dart';
import 'package:coldigui/features/offline/presentation/pages/offline_settings_widgets/coldigom_section.dart';
import 'package:coldigui/features/offline/presentation/pages/offline_settings_widgets/offline_kind_chips.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_cache_status_provider.dart';
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
  Set<String>? lastSelection;
  var stops = 0;
  var removes = 0;
  @override
  OfflineColdigomDownloadState build() => fixed;
  @override
  Future<void> start(
    Set<String> kindIds, {
    Set<String>? selection,
    MaterialKindTaxonomy? taxonomy,
  }) async {
    started.add(kindIds);
    lastSelection = selection;
  }
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

class _FixedCacheStatus extends OfflineCacheStatusNotifier {
  _FixedCacheStatus({this.refreshError});

  /// Quando não nulo, [refresh] lança este erro.
  final Object? refreshError;
  var refreshAllCalls = 0;
  var refreshCalls = 0;

  @override
  OfflineCacheStatus build() =>
      const OfflineCacheStatus(diskUsageBytes: 5 * 1024 * 1024);

  @override
  Future<void> refreshAll() async => refreshAllCalls++;

  @override
  Future<void> refresh({int? removedCount}) async {
    refreshCalls++;
    final error = refreshError;
    if (error != null) throw error;
  }
}

class _BusyLock extends OfflineMaintenanceLock {
  @override
  OfflineMaintenanceOwner? build() => OfflineMaintenanceOwner.reconcile;
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

Future<({_FixedSync sync, _FixedDownload download, _FixedCacheStatus cache})>
_pump(
  WidgetTester tester, {
  bool loggedIn = true,
  ColdigomCatalogSyncState syncState = const ColdigomCatalogSyncState(
    count: 1690,
  ),
  OfflineColdigomDownloadState downloadState =
      const OfflineColdigomDownloadState(),
  Map<String, int> rank = const {'k-grade': 0, 'k-play': 1},
  OfflineColdigomStats stats = _stats,
  List<Override> extra = const [],
  Object? cacheRefreshError,
}) async {
  final sync = _FixedSync(syncState);
  final download = _FixedDownload(downloadState);
  final cache = _FixedCacheStatus(refreshError: cacheRefreshError);
  await pumpApp(
    tester,
    const SingleChildScrollView(child: ColdigomOfflineSection()),
    overrides: [
      sharedPreferencesProvider.overrideWithValue(_prefs),
      authStateProvider.overrideWith(loggedIn ? _LoggedIn.new : _LoggedOut.new),
      favoriteMaterialKindRankProvider.overrideWithValue(rank),
      offlineColdigomStatsProvider.overrideWith((ref) async => stats),
      coldigomCatalogSyncProvider.overrideWith(() => sync),
      offlineColdigomDownloadProvider.overrideWith(() => download),
      offlineCacheStatusProvider.overrideWith(() => cache),
      ...extra,
    ],
  );
  await tester.pumpAndSettle();
  return (sync: sync, download: download, cache: cache);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  testWidgets(
    'deslogado: lista Tipos inteira e baixa sem conta; entrar é opcional',
    (tester) async {
      // Rank não vazio: prova que o guard `signedIn` o ignora deslogado.
      final handles = await _pump(
        tester,
        loggedIn: false,
        rank: const {'k-grade': 0, 'k-play': 1},
      );

      expect(
        find.text('Entre com Google para ver os seus tipos favoritos primeiro'),
        findsOneWidget,
      );
      expect(find.byType(GoogleSignInButton), findsOneWidget);
      expect(find.text('Tipos'), findsOneWidget);
      expect(find.text('Seus tipos favoritos'), findsNothing);
      expect(find.text('Outros tipos'), findsNothing);
      final chips = tester
          .widgetList<OfflineKindChip>(find.byType(OfflineKindChip))
          .map((t) => t.kind.kindName)
          .toList();
      expect(chips, ['Cifra', 'Grade', 'Playback']);
      expect(
        tester
            .widgetList<OfflineKindChip>(find.byType(OfflineKindChip))
            .every((t) => t.checked == false),
        isTrue,
        reason: 'deslogado nada vem pré-marcado pelo rank',
      );

      await tester.tap(find.widgetWithText(OfflineKindChip, 'Grade'));
      await tester.pumpAndSettle();
      final baixar = find.textContaining('Baixar selecionados');
      await tester.ensureVisible(baixar);
      await tester.tap(baixar);
      await tester.pumpAndSettle();

      expect(handles.download.started.single, {'k-grade'});
    },
  );

  testWidgets(
    'linha de estado: catálogo + disco e um só Atualizar (sync + reconcile)',
    (tester) async {
      final handles = await _pump(tester);
      expect(find.textContaining('Catálogo: 1690 louvores'), findsOneWidget);
      expect(find.textContaining('Acervo offline: 5,0 MB'), findsOneWidget);
      expect(find.text('Atualizar'), findsOneWidget);

      await tester.tap(find.text('Atualizar'));
      await tester.pumpAndSettle();

      expect(handles.sync.syncCalls, 1);
      expect(handles.cache.refreshAllCalls, 1);

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

      final chips = tester
          .widgetList<OfflineKindChip>(find.byType(OfflineKindChip))
          .toList();
      expect(chips.map((t) => t.kind.kindName), ['Grade', 'Playback']);
      expect(chips.every((t) => t.checked == true), isTrue);
      expect(find.text('Outros tipos'), findsOneWidget);
      expect(find.text('Cifra'), findsNothing);
      expect(find.textContaining('4/10 arq.'), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsWidgets);
      expect(find.byIcon(Icons.storage_outlined), findsWidgets);
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

      await tester.tap(find.widgetWithText(OfflineKindChip, 'Playback'));
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
      find.widgetWithText(TextButton, 'Remover todos os baixados'),
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

    await tester.tap(find.text('Remover todos os baixados'));
    await tester.pumpAndSettle();
    expect(find.text('Remover todos os baixados?'), findsOneWidget);
    expect(
      find.text(
        'Todos os PDFs e áudios guardados no aparelho saem, incluindo os '
        'abertos recentemente. Cifras, gestos e letras ficam.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(handles.download.removes, 1);
    expect(find.text('1 PDFs e 2 áudios removidos'), findsOneWidget);
    expect(handles.cache.refreshCalls, 1);
  });

  testWidgets('remover: falha ao reler o uso de disco só vai para o log', (
    tester,
  ) async {
    final handles = await _pump(
      tester,
      cacheRefreshError: StateError('disco indisponível'),
    );
    await tester.tap(find.text('Remover todos os baixados'));
    await tester.pumpAndSettle();

    // Restaurado ainda no corpo: o binding confere o `debugPrint` no fim.
    final logs = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    try {
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
    } finally {
      debugPrint = originalDebugPrint;
    }

    expect(handles.cache.refreshCalls, 1);
    expect(find.text('1 PDFs e 2 áudios removidos'), findsOneWidget);
    expect(logs, contains(contains('disco indisponível')));
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

  testWidgets(
    'com taxonomia: seções por classe taxonômica e Outros tipos fechado quando logado',
    (tester) async {
      final taxonomy = MaterialKindTaxonomy(
        classes: const [
          MaterialKindClass(id: 'regencia', label: 'Regência e geral'),
          MaterialKindClass(id: 'metais', label: 'Metais'),
        ],
        kinds: const {
          'k-grade': MaterialKindTaxon(
            name: 'Grade',
            classId: 'regencia',
            order: 10,
          ),
          'k-play': MaterialKindTaxon(
            name: 'Playback',
            classId: 'regencia',
            order: 20,
          ),
          'k-cifra': MaterialKindTaxon(
            name: 'Cifra',
            classId: 'metais',
            order: 10,
          ),
        },
      );

      await _pump(
        tester,
        extra: [
          coldigomKindTaxonomyProvider.overrideWithValue(taxonomy),
        ],
      );

      // Logado: Seus tipos favoritos (Grade e Playback) aparecem no topo com cabeçalho
      expect(find.text('SEUS TIPOS FAVORITOS'), findsOneWidget);
      expect(find.widgetWithText(OfflineKindChip, 'Grade'), findsOneWidget);
      expect(find.widgetWithText(OfflineKindChip, 'Playback'), findsOneWidget);

      // Outros tipos fechado
      expect(find.text('METAIS'), findsNothing);

      // Abre Outros tipos -> Seção METAIS com Cifra
      await tester.tap(find.text('Outros tipos'));
      await tester.pumpAndSettle();
      expect(find.text('METAIS'), findsOneWidget);
      expect(find.widgetWithText(OfflineKindChip, 'Cifra'), findsOneWidget);
    },
  );

  testWidgets(
    'família de tipos: exibe variante count e dados de armazenamento; expande variantes',
    (tester) async {
      const familyStats = OfflineColdigomStats({
        'alto': ColdigomKindStats(
          kindId: 'alto',
          kindName: 'Saxofone alto',
          total: 5,
          downloaded: 5,
          bytesKnown: 0,
          bytesEstimated: 5 * 200 * 1024,
          pendingBytes: 0,
        ),
        'tenor': ColdigomKindStats(
          kindId: 'tenor',
          kindName: 'Saxofone tenor',
          total: 3,
          downloaded: 0,
          bytesKnown: 0,
          bytesEstimated: 3 * 300 * 1024,
          pendingBytes: 3 * 300 * 1024,
        ),
      });

      final taxonomy = MaterialKindTaxonomy(
        classes: const [
          MaterialKindClass(id: 'metais', label: 'Metais'),
        ],
        kinds: const {
          'sax': MaterialKindTaxon(name: 'Saxofone', classId: 'metais'),
          'alto': MaterialKindTaxon(
            name: 'Saxofone alto',
            classId: 'metais',
            parentId: 'sax',
            order: 10,
          ),
          'tenor': MaterialKindTaxon(
            name: 'Saxofone tenor',
            classId: 'metais',
            parentId: 'sax',
            order: 20,
          ),
        },
      );

      await _pump(
        tester,
        loggedIn: false,
        stats: familyStats,
        extra: [
          coldigomKindTaxonomyProvider.overrideWithValue(taxonomy),
        ],
      );

      expect(find.text('METAIS'), findsOneWidget);
      // Família Saxofone recolhida
      expect(
        find.widgetWithText(OfflineKindFamilyChip, 'Saxofone'),
        findsOneWidget,
      );
      expect(find.text('Saxofone alto'), findsNothing);

      // Abre variantes
      await tester.tap(find.byTooltip('Ver variantes de Saxofone'));
      await tester.pumpAndSettle();

      expect(find.text('Saxofone alto'), findsOneWidget);
      expect(find.text('Saxofone tenor'), findsOneWidget);

      // Alto está 100% baixado -> ícone de checkmark presente
      expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);

      // Toca em Saxofone (corpo) para selecionar a família inteira
      await tester.tap(find.widgetWithText(OfflineKindFamilyChip, 'Saxofone'));
      await tester.pumpAndSettle();

      // Botão de download reflete os pendingBytes do tenor
      expect(find.textContaining('Baixar selecionados (~'), findsOneWidget);
    },
  );

  testWidgets(
    'subdivisão por material type: desmarcar áudio exclui os bytes e alvos do download',
    (tester) async {
      const stats = OfflineColdigomStats({
        'k-multi': ColdigomKindStats(
          kindId: 'k-multi',
          kindName: 'Multi Material',
          total: 15,
          downloaded: 0,
          bytesKnown: 0,
          bytesEstimated: 15 * 1024 * 1024,
          pendingBytes: 15 * 1024 * 1024,
          types: {
            MaterialKind.pdf: ColdigomTypeStats(
              kind: MaterialKind.pdf,
              rawType: 'pdf',
              total: 10,
              downloaded: 0,
              bytesKnown: 0,
              bytesEstimated: 10 * 1024 * 1024,
              pendingBytes: 10 * 1024 * 1024,
            ),
            MaterialKind.audio: ColdigomTypeStats(
              kind: MaterialKind.audio,
              rawType: 'mp3',
              total: 5,
              downloaded: 0,
              bytesKnown: 0,
              bytesEstimated: 5 * 1024 * 1024,
              pendingBytes: 5 * 1024 * 1024,
            ),
          },
        ),
      });

      final handles = await _pump(
        tester,
        loggedIn: false,
        stats: stats,
      );

      // Card exibe total com ícones de pasta e storage
      expect(find.text('Multi Material'), findsOneWidget);
      expect(find.text('15 arq.'), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsWidgets);
      expect(find.byIcon(Icons.storage_outlined), findsWidgets);

      // Subdivisão por tipo de material visível com seus ícones e contagens
      expect(find.text('Partituras'), findsOneWidget);
      expect(find.text('Áudio'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      // Marca o kind para download
      await tester.tap(find.widgetWithText(OfflineKindChip, 'Multi Material'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Baixar selecionados (~15,0 MB)'), findsOneWidget);

      // Desmarca apenas Áudio
      await tester.tap(find.text('Áudio'));
      await tester.pumpAndSettle();

      // Botão de download agora reflete apenas os 10 PDFs (~10,0 MB)
      expect(find.textContaining('Baixar selecionados (~10,0 MB)'), findsOneWidget);

      // Inicia o download e verifica que selection foi enviada para o usecase
      await tester.tap(find.textContaining('Baixar selecionados'));
      await tester.pumpAndSettle();

      expect(handles.download.started, [{'k-multi'}]);
      expect(handles.download.lastSelection, {'k-multi:pdf'});
    },
  );
}
