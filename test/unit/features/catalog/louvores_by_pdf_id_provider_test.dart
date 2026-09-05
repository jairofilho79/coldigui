import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_group_id.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_by_pdf_id_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

Louvor _louvor(String numero, String pdf) => Louvor.fromManifest(
  nome: 'Louvor $numero',
  numero: numero,
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
  pdf: pdf,
  pdfId: encodePdfId('ColAdultos/$pdf'),
  groupId: LouvorGroupId.compute(numero: numero, nome: 'Louvor $numero'),
);

void main() {
  test(
    'indexa os louvores por pdfId e reutiliza o mapa entre leituras',
    () async {
      final a = _louvor('001', '001.pdf');
      final b = _louvor('002', '002.pdf');
      final container = ProviderContainer(
        overrides: [
          louvoresManifestOverride(LouvoresManifest.fromLouvores([a, b])),
        ],
      );
      addTearDown(container.dispose);

      await container.read(louvoresManifestProvider.future);
      final map = container.read(louvoresByPdfIdProvider);

      expect(map.length, 2);
      expect(map[a.pdfId], same(a));
      expect(map[b.pdfId], same(b));
      expect(identical(map, container.read(louvoresByPdfIdProvider)), isTrue);
    },
  );

  test('sem manifest carregado devolve mapa vazio', () {
    final container = ProviderContainer(
      overrides: [louvoresManifestLoadingOverride()],
    );
    addTearDown(container.dispose);

    expect(container.read(louvoresByPdfIdProvider), isEmpty);
  });
}
