import 'dart:async';
import 'dart:convert';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/network/connectivity_stream_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/legacy_material_ids_normalizer_provider.dart';
import 'package:coldigui/features/offline/data/providers/offline_repository_providers.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_entry.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_maintenance_lock_provider.dart';
import 'package:coldigui/features/playlists/data/providers/playlist_providers.dart';
import 'package:coldigui/features/playlists/domain/entities/saved_playlist.dart';
import 'package:coldigui/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_session_prefs.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fakes/fake_auth_notifier.dart';
import '../../../support/fakes/fake_playlists_notifier.dart';

final _legadoA = encodePdfId('ColAdultos/001.pdf');
final _legadoB = encodePdfId('ColAdultos/002.pdf');
final _coldigomA = encodePdfId('assets/praises/p1/m1.pdf');
final _coldigomB = encodePdfId('assets/praises/p2/m2.pdf');

class _Resolver {
  _Resolver(this.answer, {this.gate});

  final Map<String, String> answer;
  final Completer<void>? gate;
  final calls = <Set<String>>[];

  Future<Map<String, String>> call(Iterable<String> ids) async {
    calls.add(ids.toSet());
    await gate?.future;
    return answer;
  }
}

/// Uma lista com um id legado; guarda o `syncStatus` pedido a cada `update`.
class _PlaylistRepo extends Fake implements PlaylistRepository {
  _PlaylistRepo(this.playlist);

  final SavedPlaylist playlist;
  final updates = <PlaylistSyncStatus?>[];

  @override
  Future<List<SavedPlaylist>> getAll() async => [playlist];

  @override
  Future<SavedPlaylist?> getById(String playlistId) async => playlist;

  @override
  Future<void> update(
    String playlistId, {
    String? nome,
    List<PlaylistEntry>? entries,
    List<String>? pdfIds,
    List<String>? audioIds,
    bool? salva,
    DateTime? savedAt,
    DateTime? favoritedAt,
    bool? favorita,
    bool clearFavoritedAt = false,
    DateTime? updatedAt,
    int? version,
    PlaylistSyncStatus? syncStatus,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) async {
    updates.add(syncStatus);
  }
}

/// Índice offline vazio.
class _EmptyOfflineRepo extends Fake implements OfflinePdfRepository {
  @override
  Future<List<OfflinePdfEntry>> listAll() async => const [];
}

/// Índice offline com PDFs legados; [remapPdfIds] troca as chaves e regista
/// cada lote.
class _LegacyOfflineRepo extends Fake implements OfflinePdfRepository {
  _LegacyOfflineRepo(Iterable<String> pdfIds) : pdfIds = pdfIds.toSet();

  final Set<String> pdfIds;
  final remaps = <Map<String, String>>[];

  @override
  Future<List<OfflinePdfEntry>> listAll() async => [
    for (final pdfId in pdfIds)
      OfflinePdfEntry(
        pdfId: pdfId,
        absolutePath: '/docs/$pdfId.pdf',
        category: 'x',
        fileSize: 4,
        downloadedAt: DateTime.utc(2026, 9),
        lastAccessedAt: null,
        isPersistent: true,
      ),
  ];

  @override
  Future<int> remapPdfIds(
    Map<String, String> fromTo, {
    Set<String> remove = const {},
  }) async {
    remaps.add(fromTo);
    var changed = 0;
    for (final MapEntry(key: from, value: to) in fromTo.entries) {
      if (pdfIds.remove(from)) {
        pdfIds.add(to);
        changed++;
      }
    }
    return changed;
  }
}

/// Sem listas guardadas.
class _NoPlaylistsRepo extends Fake implements PlaylistRepository {
  @override
  Future<List<SavedPlaylist>> getAll() async => const [];
}

/// Corre [onReload] no reload pós-reescrita — o fim da rodada.
class _HookedPlaylists extends FakePlaylistsNotifier {
  _HookedPlaylists(this.onReload);

  final void Function() onReload;

  @override
  Future<void> reload() async {
    onReload();
    await super.reload();
  }
}

void main() {
  late SharedPreferences prefs;
  late FakePlaylistsNotifier playlists;
  late StreamController<bool> connectivity;
  late DebugPrintCallback originalDebugPrint;
  final logs = <String>[];

  setUp(() {
    connectivity = StreamController<bool>();
    LegacyMaterialIdsNormalizer.reconnectDebounce = Duration.zero;
    logs.clear();
    originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
  });

  tearDown(() async {
    debugPrint = originalDebugPrint;
    LegacyMaterialIdsNormalizer.reconnectDebounce = const Duration(seconds: 2);
    await connectivity.close();
  });

  Future<void> boot(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
    await prefs.reload();
  }

  ProviderContainer container(
    _Resolver resolver, {
    // Sem Isar: só as prefs entram na rodada (spec §6.2).
    IsarStatus isar = IsarStatus.unavailable,
    List<Override> overrides = const [],
    FakePlaylistsNotifier? playlistsNotifier,
  }) {
    playlists = playlistsNotifier ?? FakePlaylistsNotifier();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarStatusProvider.overrideWithValue(isar),
        legacyPdfIdResolverProvider.overrideWithValue(resolver.call),
        playlistsProvider.overrideWith(() => playlists),
        connectivityStreamProvider.overrideWith((ref) => connectivity.stream),
        ...overrides,
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('sem Isar normaliza as prefs e recarrega quem as lê', () async {
    await boot({
      StorageKeys.recentlyOpened: jsonEncode([_legadoA]),
      StorageKeys.pdfLastPages: jsonEncode([
        {'id': _legadoA, 'p': 4},
      ]),
      kCarouselFocusedPdfIdPrefsKey: '$_legadoA#1',
    });
    final resolver = _Resolver({_legadoA: _coldigomA});
    final c = container(resolver);
    expect(c.read(carouselFocusedKeyProvider), '$_legadoA#1');

    final outcome = await c
        .read(legacyMaterialIdsNormalizerProvider.notifier)
        .run();

    expect(resolver.calls.single, {_legadoA});
    expect(outcome.rewritten, 3);
    expect(jsonDecode(prefs.getString(StorageKeys.recentlyOpened)!), [
      _coldigomA,
    ]);
    expect(c.read(carouselFocusedKeyProvider), '$_coldigomA#1');
    expect(playlists.reloadCalls, 1);
    expect(c.read(legacyMaterialIdsNormalizerProvider), same(outcome));
  });

  test('sem ids legados não chama o crosswalk nem recarrega', () async {
    await boot({
      StorageKeys.recentlyOpened: jsonEncode([_coldigomA]),
    });
    final resolver = _Resolver(const {});
    final c = container(resolver);

    final outcome = await c
        .read(legacyMaterialIdsNormalizerProvider.notifier)
        .run();

    expect(resolver.calls, isEmpty);
    expect(outcome.legacy, 0);
    expect(playlists.reloadCalls, 0);
  });

  test('duas chamadas simultâneas partilham a rodada', () async {
    await boot({
      StorageKeys.recentlyOpened: jsonEncode([_legadoA]),
    });
    final gate = Completer<void>();
    final resolver = _Resolver({_legadoA: _coldigomA}, gate: gate);
    final c = container(resolver);
    final notifier = c.read(legacyMaterialIdsNormalizerProvider.notifier);

    final first = notifier.run();
    final second = notifier.run();
    gate.complete();
    await Future.wait([first, second]);

    expect(resolver.calls, hasLength(1));
  });

  test(
    'id legado que chega durante a rodada entra na rodada seguinte',
    () async {
      // O cenário do boot: o hydrate está à espera do crosswalk e o pull da
      // sync grava um legado novo (cliente antigo) e pede outra rodada.
      await boot({
        StorageKeys.recentlyOpened: jsonEncode([_legadoA]),
      });
      final gate = Completer<void>();
      final resolver = _Resolver({
        _legadoA: _coldigomA,
        _legadoB: _coldigomB,
      }, gate: gate);
      final c = container(resolver);
      final notifier = c.read(legacyMaterialIdsNormalizerProvider.notifier);

      final first = notifier.run();
      await pumpEventQueue();
      expect(resolver.calls, [
        {_legadoA},
      ], reason: 'a primeira rodada já recolheu e espera o crosswalk');
      await prefs.setString(kCarouselFocusedPdfIdPrefsKey, '$_legadoB#1');
      final second = notifier.run();
      gate.complete();

      final outcome = await second;
      await first;

      expect(resolver.calls, [
        {_legadoA},
        {_legadoB},
      ]);
      expect(outcome.rewritten, 1);
      expect(prefs.getString(kCarouselFocusedPdfIdPrefsKey), '$_coldigomB#1');
      expect(jsonDecode(prefs.getString(StorageKeys.recentlyOpened)!), [
        _coldigomA,
      ]);
    },
  );

  test('pedidos durante a rodada viram uma só rodada a mais', () async {
    await boot({
      StorageKeys.recentlyOpened: jsonEncode([_legadoA]),
    });
    final gate = Completer<void>();
    final resolver = _Resolver({
      _legadoA: _coldigomA,
      _legadoB: _coldigomB,
    }, gate: gate);
    final c = container(resolver);
    final notifier = c.read(legacyMaterialIdsNormalizerProvider.notifier);

    final first = notifier.run();
    await pumpEventQueue();
    // Um legado novo e três pedidos: uma rodada a mais, não três.
    await prefs.setString(
      StorageKeys.recentlyOpened,
      jsonEncode([_legadoA, _legadoB]),
    );
    final followUps = [notifier.run(), notifier.run(), notifier.run()];
    gate.complete();
    await Future.wait([first, ...followUps]);

    expect(resolver.calls, hasLength(2));
  });

  test('falha inesperada vira pendente e não lança', () async {
    // Sem `sharedPreferencesProvider`: montar as stores explode.
    final c = ProviderContainer(
      overrides: [
        isarStatusProvider.overrideWithValue(IsarStatus.unavailable),
        legacyPdfIdResolverProvider.overrideWithValue(_Resolver(const {}).call),
        connectivityStreamProvider.overrideWith((ref) => connectivity.stream),
      ],
    );
    addTearDown(c.dispose);

    final outcome = await c
        .read(legacyMaterialIdsNormalizerProvider.notifier)
        .run();

    expect(outcome.pending, isTrue);
    expect(logs, contains(startsWith('[legacy-ids] normalização abortada')));
  });

  group('a rede voltou (offline → online)', () {
    /// Como o `ShellScaffold`: sem ouvinte o provider fica pausado e a escuta
    /// da conectividade também.
    void keepAlive(ProviderContainer c) =>
        c.listen(legacyMaterialIdsNormalizerProvider, (_, _) {});

    test('pede uma rodada', () async {
      await boot({
        StorageKeys.recentlyOpened: jsonEncode([_legadoA]),
      });
      final resolver = _Resolver({_legadoA: _coldigomA});
      final c = container(resolver);
      keepAlive(c);

      connectivity.add(false);
      await pumpEventQueue();
      expect(resolver.calls, isEmpty);

      connectivity.add(true);
      await pumpEventQueue();

      expect(resolver.calls, hasLength(1));
      expect(jsonDecode(prefs.getString(StorageKeys.recentlyOpened)!), [
        _coldigomA,
      ]);
    });

    test('online no boot ou online → online não pede', () async {
      await boot({
        StorageKeys.recentlyOpened: jsonEncode([_legadoA]),
      });
      final resolver = _Resolver({_legadoA: _coldigomA});
      final c = container(resolver);
      keepAlive(c);

      connectivity
        ..add(true)
        ..add(true);
      await pumpEventQueue();

      expect(resolver.calls, isEmpty);
    });

    test('com uma rodada em voo não abre outra em paralelo', () async {
      await boot({
        StorageKeys.recentlyOpened: jsonEncode([_legadoA]),
      });
      final gate = Completer<void>();
      final resolver = _Resolver({_legadoA: _coldigomA}, gate: gate);
      final c = container(resolver);
      keepAlive(c);
      final running = c
          .read(legacyMaterialIdsNormalizerProvider.notifier)
          .run();

      connectivity
        ..add(false)
        ..add(true);
      await pumpEventQueue();
      gate.complete();
      await running;
      await pumpEventQueue();

      expect(resolver.calls, hasLength(1));
    });
  });

  group('índice offline com a manutenção ocupada', () {
    const reconcile = OfflineMaintenanceOwner.reconcile;

    ProviderContainer offlineContainer(
      _Resolver resolver,
      _LegacyOfflineRepo offline, {
      FakePlaylistsNotifier? playlistsNotifier,
    }) {
      final c = container(
        resolver,
        isar: IsarStatus.available,
        playlistsNotifier: playlistsNotifier,
        overrides: [
          playlistRepositoryProvider.overrideWithValue(_NoPlaylistsRepo()),
          offlinePdfRepositoryProvider.overrideWithValue(offline),
        ],
      );
      // Como o `ShellScaffold`: sem ouvinte o provider fica pausado.
      c.listen(legacyMaterialIdsNormalizerProvider, (_, _) {});
      return c;
    }

    test('adia a rodada e corre uma só a mais quando o lock solta', () async {
      await boot({});
      final resolver = _Resolver({_legadoA: _coldigomA});
      final offline = _LegacyOfflineRepo({_legadoA});
      final c = offlineContainer(resolver, offline);
      final lock = c.read(offlineMaintenanceLockProvider.notifier);
      expect(lock.tryAcquire(reconcile), isTrue);

      final outcome = await c
          .read(legacyMaterialIdsNormalizerProvider.notifier)
          .run();

      expect(outcome.deferred, isTrue);
      expect(offline.remaps, isEmpty);
      await pumpEventQueue();
      expect(resolver.calls, hasLength(1), reason: 'espera o lock');

      lock.release(reconcile);
      await pumpEventQueue();

      expect(resolver.calls, hasLength(2));
      expect(offline.remaps, [
        {_legadoA: _coldigomA},
      ]);
      expect(offline.pdfIds, {_coldigomA});
      expect(c.read(legacyMaterialIdsNormalizerProvider)?.deferred, isFalse);
      expect(c.read(offlineMaintenanceLockProvider), isNull);

      // Já não há nada adiado: outra volta do lock não pede rodada.
      expect(lock.tryAcquire(reconcile), isTrue);
      lock.release(reconcile);
      await pumpEventQueue();
      expect(resolver.calls, hasLength(2));
    });

    test(
      'lock que solta antes do fim da rodada adiada: corre na hora',
      () async {
        await boot({
          StorageKeys.recentlyOpened: jsonEncode([_legadoA]),
        });
        final resolver = _Resolver({_legadoA: _coldigomA});
        final offline = _LegacyOfflineRepo({_legadoA});
        late ProviderContainer c;
        // O reload é o último passo da rodada: a store offline já adiou, mas o
        // desfecho ainda não saiu.
        final hooked = _HookedPlaylists(
          () => c
              .read(offlineMaintenanceLockProvider.notifier)
              .release(reconcile),
        );
        c = offlineContainer(resolver, offline, playlistsNotifier: hooked);
        c.read(offlineMaintenanceLockProvider.notifier).tryAcquire(reconcile);

        final outcome = await c
            .read(legacyMaterialIdsNormalizerProvider.notifier)
            .run();
        expect(outcome.deferred, isTrue);
        await pumpEventQueue();

        expect(resolver.calls, hasLength(2));
        expect(offline.pdfIds, {_coldigomA});
      },
    );
  });

  group('dono das listas (sub da sessão, lido na hora da reescrita)', () {
    const sub = 'sub-1';

    Future<List<PlaylistSyncStatus?>> rewriteWhile({
      required AuthUser? atStart,
      required AuthUser? atRewrite,
    }) async {
      await boot({});
      final repo = _PlaylistRepo(
        SavedPlaylist(
          playlistId: 'pl-1',
          nome: 'Culto',
          createdAt: DateTime.utc(2026, 9, 22),
          updatedAt: DateTime.utc(2026, 9, 22),
          entries: [PlaylistEntry.classified(_legadoA)],
          salva: true,
          syncStatus: PlaylistSyncStatus.synced,
          ownerSub: sub,
        ),
      );
      final auth = FakeAuthNotifier(atStart);
      final gate = Completer<void>();
      final c = container(
        _Resolver({_legadoA: _coldigomA}, gate: gate),
        isar: IsarStatus.available,
        overrides: [
          playlistRepositoryProvider.overrideWithValue(repo),
          offlinePdfRepositoryProvider.overrideWithValue(_EmptyOfflineRepo()),
          authStateProvider.overrideWith(() => auth),
        ],
      );
      await c.read(authStateProvider.future);

      final running = c
          .read(legacyMaterialIdsNormalizerProvider.notifier)
          .run();
      await pumpEventQueue();
      // Entre a coleta e a reescrita a sessão muda.
      auth.setUser(atRewrite);
      gate.complete();
      await running;
      return repo.updates;
    }

    test('lista da conta corrente passa a pendingPush', () async {
      final updates = await rewriteWhile(
        atStart: null,
        atRewrite: const AuthUser(googleSub: sub, sessionToken: 't'),
      );
      // `null` = o repositório aplica a regra de sempre (pendingPush).
      expect(updates, [null]);
    });

    test('sem sessão na reescrita a lista guarda o syncStatus', () async {
      final updates = await rewriteWhile(
        atStart: const AuthUser(googleSub: sub, sessionToken: 't'),
        atRewrite: null,
      );
      expect(updates, [PlaylistSyncStatus.synced]);
    });
  });
}
