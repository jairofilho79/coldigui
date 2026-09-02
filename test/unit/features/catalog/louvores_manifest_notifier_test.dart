import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/catalog/data/providers/catalog_providers.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:coldigui/features/catalog/domain/usecases/load_louvores_manifest.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });

  final List<Louvor> cached;
  final List<Louvor> remote;
  final Object? remoteError;

  /// Simula `/api/catalog/checksum` respondendo 204 (nada mudou).
  final bool checksumUnchanged;

  /// Checksum devolvido pelo sync para o notifier persistir.
  final String? syncedChecksum;

  var loadManifestCalls = 0;
  var syncCalls = 0;
  List<Louvor>? lastSyncCached;
  String? lastKnownChecksum;

  @override
  Future<List<Louvor>> loadCachedLouvores() async => List.of(cached);

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
  Future<String?> fetchManifestChecksum() async => null;

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
        isarAvailableProvider.overrideWithValue(isarAvailable),
        catalogRepositoryProvider.overrideWithValue(repository),
        loadLouvoresManifestProvider.overrideWith(
          (ref) => LoadLouvoresManifest(repository),
        ),
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
    expect(repository.loadManifestCalls, 1);
    expect(repository.syncCalls, 0);
  });

  test('sem Isar disponível ignora cache e busca remoto', () async {
    final repository = _FakeCatalogRepository(
      cached: [_louvor('cached-1')],
      remote: [_louvor('remote-1')],
    );

    final container = createContainer(repository, isarAvailable: false);

    final manifest = await container.read(louvoresManifestProvider.future);

    expect(manifest.louvores.first.pdfId, 'remote-1');
    expect(repository.loadManifestCalls, 1);
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
