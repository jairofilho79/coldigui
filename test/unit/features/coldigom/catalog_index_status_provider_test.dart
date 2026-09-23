import 'dart:async';

import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

void main() {
  final ready = catalogIndexOf([catalogGroup(praiseId: 'p1', name: 'Aleluia')]);

  ProviderContainer container({
    required Future<ColdigomSearchIndex> Function() hydration,
    ColdigomCatalogSyncState sync = const ColdigomCatalogSyncState(),
  }) {
    final c = ProviderContainer(
      overrides: [
        coldigomCatalogHydrationProvider.overrideWith((ref) => hydration()),
        coldigomCatalogSyncProvider.overrideWith(
          () => FakeColdigomCatalogSyncNotifier(sync),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<CatalogIndexStatus> settled(ProviderContainer c) async {
    await c.read(coldigomCatalogHydrationProvider.future);
    return c.read(catalogIndexStatusProvider);
  }

  test('índice com praises → ready, mesmo com um sync falhado', () async {
    final c = container(
      hydration: () async => ready,
      sync: const ColdigomCatalogSyncState(
        lastResult: ColdigomCatalogSyncFailed('x'),
      ),
    );
    expect(await settled(c), CatalogIndexStatus.ready);
  });

  test('hidratação em curso → loading', () {
    final pending = Completer<ColdigomSearchIndex>();
    final c = container(hydration: () => pending.future);
    expect(c.read(catalogIndexStatusProvider), CatalogIndexStatus.loading);
  });

  test('índice vazio + sync em voo → loading', () async {
    final c = container(
      hydration: () async => ColdigomSearchIndex.empty,
      sync: const ColdigomCatalogSyncState(isSyncing: true),
    );
    expect(await settled(c), CatalogIndexStatus.loading);
  });

  test('índice vazio + sync falhado → failed', () async {
    final c = container(
      hydration: () async => ColdigomSearchIndex.empty,
      sync: const ColdigomCatalogSyncState(
        lastResult: ColdigomCatalogSyncFailed('sem rede'),
      ),
    );
    expect(await settled(c), CatalogIndexStatus.failed);
  });

  test('índice vazio sem tentativa de sync ainda → loading', () async {
    final c = container(hydration: () async => ColdigomSearchIndex.empty);
    expect(await settled(c), CatalogIndexStatus.loading);
  });

  test('índice vazio depois de um sync bem-sucedido → ready', () async {
    final c = container(
      hydration: () async => ColdigomSearchIndex.empty,
      sync: const ColdigomCatalogSyncState(
        lastResult: ColdigomCatalogSyncNoop(),
      ),
    );
    expect(await settled(c), CatalogIndexStatus.ready);
  });
}
