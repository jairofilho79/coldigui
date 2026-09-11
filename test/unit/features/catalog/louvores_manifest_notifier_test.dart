import 'dart:async';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/data/providers/catalog_providers.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

Louvor _louvor(String pdfId) => Louvor.fromManifest(
  nome: 'Louvor',
  numero: '001',
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
  pdf: '001.pdf',
  pdfId: pdfId,
);

class _FakeCatalogRepository implements CatalogRepository {
  _FakeCatalogRepository({
    this.cached = const [],
    this.remote = const [],
    this.remoteError,
    this.checksumUnchanged = false,
    this.syncedChecksum,
    this.remoteChecksum,
  });

  final List<Louvor> cached;
  final List<Louvor> remote;
  final Object? remoteError;

  /// Simula `/api/catalog/checksum` respondendo 204 (nada mudou).
  final bool checksumUnchanged;

  /// Checksum devolvido pelo sync para o notifier persistir.
  final String? syncedChecksum;

  /// Resposta de `GET /api/catalog/checksum` (prefetch do boot, A8).
  final String? remoteChecksum;

  var loadManifestCalls = 0;
  var syncCalls = 0;
  var checksumCalls = 0;
  var loadCachedCalls = 0;
  List<Louvor>? lastSyncCached;
  String? lastKnownChecksum;

  /// `false` enquanto o datasource local é o `unavailable()` do modo degradado.
  var isarOpen = true;

  @override
  Future<List<Louvor>> loadCachedLouvores() async {
    loadCachedCalls++;
    return isarOpen ? List.of(cached) : const [];
  }

  @override
  Future<ManifestSyncOutcome> syncManifest({
    required List<Louvor> cached,
    String? knownChecksum,
  }) async {
    syncCalls++;
    lastSyncCached = cached;
    lastKnownChecksum = knownChecksum;
    if (remoteError != null) throw remoteError!;

    if (checksumUnchanged) {
      return ManifestSyncOutcome(louvores: cached, cacheReplaced: false);
    }

    return ManifestSyncOutcome(
      louvores: List.of(remote),
      cacheReplaced: true,
      checksum: syncedChecksum,
    );
  }

  @override
  Future<List<Louvor>> loadManifest() async {
    loadManifestCalls++;
    if (remoteError != null) throw remoteError!;
    return List.of(remote);
  }

  @override
  Future<List<Louvor>> forceRefreshManifest() async => loadManifest();

  @override
  Future<void> cacheManifest(List<Louvor> louvores) async {}

  @override
  Future<String?> fetchManifestChecksum() async {
    checksumCalls++;
    return remoteChecksum;
  }

  @override
  Future<bool> isCatalogStale() async => false;
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer createContainer(
    _FakeCatalogRepository repository, {
    bool isarAvailable = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarStatusProvider.overrideWithValue(
          isarAvailable ? IsarStatus.available : IsarStatus.unavailable,
        ),
        catalogRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Container com o Isar ainda abrindo — o boot decide só quando [opener] resolver.
  ///
  /// O override de `catalogRepositoryProvider` observa `optionalIsarProvider`
  /// como a produção faz (`catalogLocalDatasourceProvider` troca de
  /// `unavailable()` para o datasource real quando o Isar abre): sem isso o
  /// teste não veria o notifier ser reconstruído no meio do boot.
  ProviderContainer createOpeningContainer(
    _FakeCatalogRepository repository,
    Future<Isar> Function() opener,
  ) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isarOpenerProvider.overrideWithValue(opener),
        catalogRepositoryProvider.overrideWith((ref) {
          repository.isarOpen = ref.watch(optionalIsarProvider) != null;
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'retorna cache imediatamente e sincroniza remoto em background',
    () async {
      final repository = _FakeCatalogRepository(
        cached: [_louvor('cached-1')],
        remote: [_louvor('remote-1')],
      );

      final container = createContainer(repository);

      final initial = await container.read(louvoresManifestProvider.future);

      expect(initial.louvores, hasLength(1));
      expect(initial.louvores.first.pdfId, 'cached-1');

      await pumpEventQueue();

      final updated = container.read(louvoresManifestProvider).value!;
      expect(updated.louvores.first.pdfId, 'remote-1');
      expect(repository.syncCalls, 1);
      expect(
        repository.loadManifestCalls,
        0,
        reason: 'boot quente passa por syncManifest, não pelo download direto',
      );
      expect(container.read(louvoresManifestProvider).isLoading, isFalse);
    },
  );

  test('sem cache aguarda fetch remoto', () async {
    final repository = _FakeCatalogRepository(remote: [_louvor('remote-only')]);

    final container = createContainer(repository);

    final manifest = await container.read(louvoresManifestProvider.future);

    expect(manifest.louvores.first.pdfId, 'remote-only');
    expect(
      repository.syncCalls,
      1,
      reason: 'boot frio passa por syncManifest para guardar o checksum (A3)',
    );
    expect(repository.loadManifestCalls, 0);
  });

  test('sem Isar disponível ignora cache e busca remoto', () async {
    final repository = _FakeCatalogRepository(
      cached: [_louvor('cached-1')],
      remote: [_louvor('remote-1')],
    );

    final container = createContainer(repository, isarAvailable: false);

    final manifest = await container.read(louvoresManifestProvider.future);

    expect(manifest.louvores.first.pdfId, 'remote-1');
    expect(repository.syncCalls, 1);
    expect(repository.lastSyncCached, isEmpty);
  });

  test('mantém cache quando refresh remoto falha', () async {
    final repository = _FakeCatalogRepository(
      cached: [_louvor('cached-1')],
      remoteError: Exception('offline'),
    );

    final container = createContainer(repository);

    await container.read(louvoresManifestProvider.future);
    await pumpEventQueue();

    final state = container.read(louvoresManifestProvider);
    expect(state.hasError, isFalse);
    expect(state.value!.louvores.first.pdfId, 'cached-1');
  });

  group('gate por checksum no refresh de background (A1)', () {
    test(
      'envia o checksum salvo e o cache em memória para syncManifest',
      () async {
        SharedPreferences.setMockInitialValues({
          StorageKeys.manifestChecksum: 'abc123',
        });
        prefs = await SharedPreferences.getInstance();

        final repository = _FakeCatalogRepository(
          cached: [_louvor('cached-1')],
          checksumUnchanged: true,
        );

        final container = createContainer(repository);

        await container.read(louvoresManifestProvider.future);
        await pumpEventQueue();

        expect(repository.lastKnownChecksum, 'abc123');
        expect(repository.lastSyncCached, hasLength(1));
        expect(repository.lastSyncCached!.single.pdfId, 'cached-1');
      },
    );

    test('checksum inalterado não emite novo estado', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.manifestChecksum: 'abc123',
      });
      prefs = await SharedPreferences.getInstance();

      final repository = _FakeCatalogRepository(
        cached: [_louvor('cached-1')],
        remote: [_louvor('remote-1')],
        checksumUnchanged: true,
      );

      final container = createContainer(repository);

      final initial = await container.read(louvoresManifestProvider.future);
      await pumpEventQueue();

      final after = container.read(louvoresManifestProvider).value!;
      expect(repository.syncCalls, 1);
      expect(
        identical(initial, after),
        isTrue,
        reason: 'sem mudança o snapshot entregue no boot é preservado',
      );
      expect(after.louvores.single.pdfId, 'cached-1');
    });

    test(
      'checksum inalterado ainda limpa o selo de catálogo desatualizado',
      () async {
        final repository = _StaleFlippingRepository(
          cached: [_louvor('cached-1')],
        );

        final container = createContainer(repository);

        final initial = await container.read(louvoresManifestProvider.future);
        expect(initial.isStale, isTrue);

        await pumpEventQueue();

        final after = container.read(louvoresManifestProvider).value!;
        expect(after.isStale, isFalse);
        expect(after.louvores.single.pdfId, 'cached-1');
        expect(
          identical(after.availableArranjos, initial.availableArranjos),
          isTrue,
          reason: 'arranjos não são recomputados só para atualizar isStale',
        );
      },
    );

    test('persiste o novo checksum devolvido pelo sync', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.manifestChecksum: 'antigo',
      });
      prefs = await SharedPreferences.getInstance();

      final repository = _FakeCatalogRepository(
        cached: [_louvor('cached-1')],
        remote: [_louvor('remote-1')],
        syncedChecksum: 'novo',
      );

      final container = createContainer(repository);

      await container.read(louvoresManifestProvider.future);
      await pumpEventQueue();

      expect(prefs.getString(StorageKeys.manifestChecksum), 'novo');
    });

    test('boot frio sem cache já persiste o checksum baixado (A3)', () async {
      final repository = _FakeCatalogRepository(
        remote: [_louvor('remote-only')],
        syncedChecksum: 'checksum-do-boot-1',
      );

      final container = createContainer(repository);

      final manifest = await container.read(louvoresManifestProvider.future);

      expect(manifest.louvores.single.pdfId, 'remote-only');
      expect(
        prefs.getString(StorageKeys.manifestChecksum),
        'checksum-do-boot-1',
        reason: 'sem isso o gate condicional só armaria no boot 3',
      );
    });

    test('não regrava o checksum quando ele não mudou', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.manifestChecksum: 'abc123',
      });
      prefs = await SharedPreferences.getInstance();

      final repository = _FakeCatalogRepository(
        cached: [_louvor('cached-1')],
        checksumUnchanged: true,
      );

      final container = createContainer(repository);

      await container.read(louvoresManifestProvider.future);
      await pumpEventQueue();

      expect(prefs.getString(StorageKeys.manifestChecksum), 'abc123');
    });
  });

  group('boot com o Isar ainda abrindo (A8)', () {
    test('pede o checksum antes do Isar resolver', () async {
      final isarGate = Completer<Isar>();
      final repository = _FakeCatalogRepository(
        cached: [_louvor('cached-1')],
        remote: [_louvor('remote-1')],
        remoteChecksum: 'fresco',
      );

      final container = createOpeningContainer(
        repository,
        () => isarGate.future,
      );

      final booted = container.read(louvoresManifestProvider.future);
      await pumpEventQueue();

      expect(
        repository.checksumCalls,
        1,
        reason: 'A8: o GET /checksum não espera o WASM + OPFS abrirem',
      );
      expect(
        repository.loadCachedCalls,
        0,
        reason: 'a decisão cache-first só acontece depois do Isar resolver',
      );

      isarGate.complete(_FakeIsar());
      final manifest = await booted;
      await pumpEventQueue();

      expect(manifest.louvores.single.pdfId, 'cached-1');
      expect(
        repository.loadCachedCalls,
        1,
        reason: 'o boot não pode ler o cache duas vezes ao Isar resolver',
      );
      expect(
        repository.syncCalls,
        1,
        reason: 'nem baixar o manifest duas vezes',
      );
    });

    test('Isar que falha ao abrir cai para o remoto', () async {
      final repository = _FakeCatalogRepository(
        cached: [_louvor('cached-1')],
        remote: [_louvor('remote-1')],
      );

      final container = createOpeningContainer(
        repository,
        () async => throw StateError('sem OPFS'),
      );

      final manifest = await container.read(louvoresManifestProvider.future);

      expect(manifest.louvores.single.pdfId, 'remote-1');
      expect(repository.lastSyncCached, isEmpty);
      expect(repository.loadCachedCalls, 0);
    });

    test(
      'checksum do boot dispensa o /checksum condicional quando mudou',
      () async {
        SharedPreferences.setMockInitialValues({
          StorageKeys.manifestChecksum: 'antigo',
        });
        prefs = await SharedPreferences.getInstance();

        final repository = _FakeCatalogRepository(
          cached: [_louvor('cached-1')],
          remote: [_louvor('remote-1')],
          remoteChecksum: 'novo',
        );

        final container = createOpeningContainer(
          repository,
          () async => _FakeIsar(),
        );

        await container.read(louvoresManifestProvider.future);
        await pumpEventQueue();

        expect(
          repository.lastKnownChecksum,
          isNull,
          reason:
              'o checksum do boot já disse que mudou — repetir o condicional '
              'seria um round-trip a mais antes do download',
        );
        expect(
          prefs.getString(StorageKeys.manifestChecksum),
          'novo',
          reason: 'sem ETag no corpo, o checksum do boot arma o gate',
        );
      },
    );

    test('checksum do boot igual ao salvo mantém o gate condicional', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.manifestChecksum: 'igual',
      });
      prefs = await SharedPreferences.getInstance();

      final repository = _FakeCatalogRepository(
        cached: [_louvor('cached-1')],
        checksumUnchanged: true,
        remoteChecksum: 'igual',
      );

      final container = createOpeningContainer(
        repository,
        () async => _FakeIsar(),
      );

      await container.read(louvoresManifestProvider.future);
      await pumpEventQueue();

      expect(repository.lastKnownChecksum, 'igual');
    });

    test('falha do prefetch do checksum não quebra o boot', () async {
      final repository = _FailingChecksumRepository(
        cached: [_louvor('cached-1')],
      );

      final container = createOpeningContainer(
        repository,
        () async => _FakeIsar(),
      );

      final manifest = await container.read(louvoresManifestProvider.future);
      await pumpEventQueue();

      expect(manifest.louvores.single.pdfId, 'cached-1');
      expect(container.read(louvoresManifestProvider).hasError, isFalse);
    });
  });

  test(
    'refresh em background não toca no notifier depois do dispose (A2)',
    () async {
      final repository = _GatedSyncRepository(cached: [_louvor('cached-1')]);

      final container = createContainer(repository);

      await container.read(louvoresManifestProvider.future);
      final staleCallsWhileMounted = repository.staleCalls;

      container.dispose();
      repository.releaseSync();
      await pumpEventQueue();

      expect(
        repository.staleCalls,
        staleCallsWhileMounted,
        reason: 'o notifier descartado não pode voltar a ler nem gravar estado',
      );
    },
  );
}

/// Fake mínimo de [Isar] — só [close] é chamado por [isarInitializerProvider].
class _FakeIsar implements Isar {
  @override
  bool close({bool deleteFromDisk = false}) => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Repositório cujo `GET /checksum` falha — rede parcial no boot.
class _FailingChecksumRepository extends _FakeCatalogRepository {
  _FailingChecksumRepository({required super.cached})
    : super(checksumUnchanged: true);

  @override
  Future<String?> fetchManifestChecksum() async {
    throw Exception('checksum offline');
  }
}

/// Repositório cujo `syncManifest` só termina quando o teste liberar.
///
/// Permite descartar o `ProviderContainer` com o refresh de background em voo.
class _GatedSyncRepository extends _FakeCatalogRepository {
  _GatedSyncRepository({required super.cached})
    : super(remote: const [], syncedChecksum: 'novo');

  final _gate = Completer<void>();
  var staleCalls = 0;

  void releaseSync() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<ManifestSyncOutcome> syncManifest({
    required List<Louvor> cached,
    String? knownChecksum,
  }) async {
    await _gate.future;
    return super.syncManifest(cached: cached, knownChecksum: knownChecksum);
  }

  @override
  Future<bool> isCatalogStale() async {
    staleCalls++;
    return false;
  }
}

/// Repositório cujo `isStale` vira `false` depois do sync bem-sucedido.
///
/// Espelha o `markSyncedNow()` que `CatalogRepositoryImpl.syncManifest` executa
/// quando o checksum confirma que o catálogo remoto não mudou.
class _StaleFlippingRepository extends _FakeCatalogRepository {
  _StaleFlippingRepository({required super.cached})
    : super(checksumUnchanged: true);

  var _stale = true;

  @override
  Future<ManifestSyncOutcome> syncManifest({
    required List<Louvor> cached,
    String? knownChecksum,
  }) async {
    _stale = false;
    return super.syncManifest(cached: cached, knownChecksum: knownChecksum);
  }

  @override
  Future<bool> isCatalogStale() async => _stale;
}
