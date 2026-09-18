import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/domain/entities/manifest_material_aliases.dart';
import 'package:coldigui/features/catalog/domain/utils/coldigom_pdf_id_from_manifest_pdf.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/manifest_material_aliases_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/louvores_manifest_test_helpers.dart';

Louvor _louvor(
  String pdfId, {
  String? praiseId,
  String? materialId,
  String pdf = '001.pdf',
}) => Louvor.fromManifest(
  nome: 'L $pdfId',
  numero: '001',
  categoria: 'Partitura',
  classificacao: 'ColAdultos',
  pdf: pdf,
  pdfId: pdfId,
  praiseId: praiseId,
  materialId: materialId,
);

void main() {
  group('coldigomPdfIdFromManifestPdf', () {
    test('extrai o r2Key da URL absoluta e codifica como o adapter', () {
      expect(
        coldigomPdfIdFromManifestPdf(
          'https://coldigom.test/assets/praises/outro-praise/m1.pdf',
        ),
        encodePdfId('assets/praises/outro-praise/m1.pdf'),
      );
    });

    test('null sem /assets/praises/ (nome de ficheiro ou URL estranha)', () {
      expect(coldigomPdfIdFromManifestPdf('001.pdf'), isNull);
      expect(coldigomPdfIdFromManifestPdf('https://x/assets/PES/a.pdf'), isNull);
      expect(coldigomPdfIdFromManifestPdf(''), isNull);
    });
  });

  group('ManifestMaterialAliases.fromLouvores', () {
    test('indexa praiseIds, materialId e alias coldigom → legado', () {
      final a = _louvor(
        'legado-a',
        praiseId: 'p1',
        materialId: 'm1',
        pdf: 'https://coldigom.test/assets/praises/p1/m1.pdf',
      );
      final b = _louvor(
        'legado-b',
        praiseId: 'p2',
        materialId: 'm2',
        // r2Key na pasta de outro praise (material movido): o alias sai da
        // URL, não do praiseId.
        pdf: 'https://coldigom.test/assets/praises/p9/m2.pdf',
      );
      final semPraise = _louvor('legado-c');

      final aliases = ManifestMaterialAliases.fromLouvores([a, b, semPraise]);

      expect(aliases.praiseIds, {'p1', 'p2'});
      expect(aliases.byMaterialId['m1'], same(a));
      expect(aliases.byMaterialId['m2'], same(b));
      expect(
        aliases.legacyPdfIdByColdigomPdfId,
        {
          encodePdfId('assets/praises/p1/m1.pdf'): 'legado-a',
          encodePdfId('assets/praises/p9/m2.pdf'): 'legado-b',
        },
      );
    });

    test('materialId repetido fica com a primeira ocorrência (F4)', () {
      final primeiro = _louvor(
        'legado-1',
        praiseId: 'p1',
        materialId: 'm1',
        pdf: 'https://coldigom.test/assets/praises/p1/m1.pdf',
      );
      final segundo = _louvor(
        'legado-2',
        praiseId: 'p1',
        materialId: 'm1',
        pdf: 'https://coldigom.test/assets/praises/p1/m1.pdf',
      );

      final aliases = ManifestMaterialAliases.fromLouvores([primeiro, segundo]);

      expect(aliases.byMaterialId['m1'], same(primeiro));
      expect(
        aliases.legacyPdfIdByColdigomPdfId[encodePdfId('assets/praises/p1/m1.pdf')],
        'legado-1',
      );
    });

    test('vazio sem praiseId em nenhuma entrada', () {
      final aliases = ManifestMaterialAliases.fromLouvores([_louvor('x')]);
      expect(aliases.praiseIds, isEmpty);
      expect(aliases.byMaterialId, isEmpty);
      expect(aliases.legacyPdfIdByColdigomPdfId, isEmpty);
    });
  });

  group('manifestMaterialAliasesProvider', () {
    test('constrói uma vez por manifest', () async {
      final container = ProviderContainer(
        overrides: [
          louvoresManifestOverride(
            LouvoresManifest.fromLouvores([
              _louvor(
                'legado-a',
                praiseId: 'p1',
                materialId: 'm1',
                pdf: 'https://coldigom.test/assets/praises/p1/m1.pdf',
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(louvoresManifestProvider.future);

      final first = container.read(manifestMaterialAliasesProvider);
      expect(first.praiseIds, {'p1'});
      expect(identical(first, container.read(manifestMaterialAliasesProvider)), isTrue);
    });

    test('empty enquanto o manifest não carregou', () {
      final container = ProviderContainer(
        overrides: [louvoresManifestLoadingOverride()],
      );
      addTearDown(container.dispose);
      expect(
        identical(
          container.read(manifestMaterialAliasesProvider),
          ManifestMaterialAliases.empty,
        ),
        isTrue,
      );
    });
  });
}
