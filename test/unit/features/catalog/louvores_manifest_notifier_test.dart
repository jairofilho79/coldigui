import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/features/catalog/data/providers/catalog_providers.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:coldigui/features/catalog/domain/usecases/load_louvores_manifest.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });

  final List<Louvor> cached;
  final List<Louvor> remote;
  final Object? remoteError;

  var loadManifestCalls = 0;

  @override
  Future<List<Louvor>> loadCachedLouvores() async => List.of(cached);

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
  test(
    'retorna cache imediatamente e sincroniza remoto em background',
    () async {
      final repository = _FakeCatalogRepository(
        cached: [_louvor('cached-1')],
        remote: [_louvor('remote-1')],
      );

      final container = ProviderContainer(
        overrides: [
          isarAvailableProvider.overrideWithValue(true),
          catalogRepositoryProvider.overrideWithValue(repository),
          loadLouvoresManifestProvider.overrideWith(
            (ref) => LoadLouvoresManifest(repository),
          ),
        ],
      );
      addTearDown(container.dispose);

      final initial = await container.read(louvoresManifestProvider.future);

      expect(initial.louvores, hasLength(1));
      expect(initial.louvores.first.pdfId, 'cached-1');

      await pumpEventQueue();

      final updated = container.read(louvoresManifestProvider).value!;
      expect(updated.louvores.first.pdfId, 'remote-1');
      expect(repository.loadManifestCalls, 1);
      expect(container.read(louvoresManifestProvider).isLoading, isFalse);
    },
  );

  test('sem cache aguarda fetch remoto', () async {
    final repository = _FakeCatalogRepository(remote: [_louvor('remote-only')]);

    final container = ProviderContainer(
      overrides: [
        isarAvailableProvider.overrideWithValue(true),
        catalogRepositoryProvider.overrideWithValue(repository),
        loadLouvoresManifestProvider.overrideWith(
          (ref) => LoadLouvoresManifest(repository),
        ),
      ],
    );
    addTearDown(container.dispose);

    final manifest = await container.read(louvoresManifestProvider.future);

    expect(manifest.louvores.first.pdfId, 'remote-only');
    expect(repository.loadManifestCalls, 1);
  });

  test('sem Isar disponível ignora cache e busca remoto', () async {
    final repository = _FakeCatalogRepository(
      cached: [_louvor('cached-1')],
      remote: [_louvor('remote-1')],
    );

    final container = ProviderContainer(
      overrides: [
        isarAvailableProvider.overrideWithValue(false),
        catalogRepositoryProvider.overrideWithValue(repository),
        loadLouvoresManifestProvider.overrideWith(
          (ref) => LoadLouvoresManifest(repository),
        ),
      ],
    );
    addTearDown(container.dispose);

    final manifest = await container.read(louvoresManifestProvider.future);

    expect(manifest.louvores.first.pdfId, 'remote-1');
    expect(repository.loadManifestCalls, 1);
  });

  test('mantém cache quando refresh remoto falha', () async {
    final repository = _FakeCatalogRepository(
      cached: [_louvor('cached-1')],
      remoteError: Exception('offline'),
    );

    final container = ProviderContainer(
      overrides: [
        isarAvailableProvider.overrideWithValue(true),
        catalogRepositoryProvider.overrideWithValue(repository),
        loadLouvoresManifestProvider.overrideWith(
          (ref) => LoadLouvoresManifest(repository),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(louvoresManifestProvider.future);
    await pumpEventQueue();

    final state = container.read(louvoresManifestProvider);
    expect(state.hasError, isFalse);
    expect(state.value!.louvores.first.pdfId, 'cached-1');
  });
}
