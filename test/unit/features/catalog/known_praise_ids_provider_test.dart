import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/presentation/providers/known_praise_ids_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

void main() {
  test('união dos ids do índice Coldigom com os praises do manifest', () async {
    final container = ProviderContainer(
      overrides: [
        louvoresManifestOverride(
          LouvoresManifest.fromLouvores([
            Louvor.fromManifest(
              nome: 'A',
              numero: '001',
              categoria: 'Partitura',
              classificacao: 'ColAdultos',
              pdf: 'https://coldigom.test/assets/praises/p-manifest/m.pdf',
              pdfId: 'legado',
              praiseId: 'p-manifest',
              materialId: 'm',
            ),
          ]),
        ),
        coldigomSearchIndexProvider.overrideWithValue(
          ColdigomSearchIndex.build(const [], catalogIds: {'p-index'}),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(louvoresManifestProvider.future);

    expect(container.read(knownPraiseIdsProvider), {'p-index', 'p-manifest'});
  });
}
