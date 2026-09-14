import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/pdf_ids_by_short_id_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

Louvor _louvor(String pdfId, {String? shortId}) => Louvor.fromManifest(
      nome: 'L $pdfId',
      numero: '001',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: '$pdfId.pdf',
      pdfId: pdfId,
      shortId: shortId,
    );

void main() {
  test('mapeia shortId → pdfId e ignora louvor sem shortId', () async {
    final container = ProviderContainer(
      overrides: [
        louvoresManifestOverride(
          LouvoresManifest.fromLouvores([
            _louvor('pdf-a', shortId: '0000'),
            _louvor('pdf-b', shortId: '1a2f'),
            _louvor('pdf-c'),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(louvoresManifestProvider.future);

    expect(container.read(pdfIdsByShortIdProvider), {
      '0000': 'pdf-a',
      '1a2f': 'pdf-b',
    });
  });

  test('vazio enquanto o manifest não carregou', () {
    final container = ProviderContainer(
      overrides: [louvoresManifestLoadingOverride()],
    );
    addTearDown(container.dispose);
    expect(container.read(pdfIdsByShortIdProvider), isEmpty);
  });
}
