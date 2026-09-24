import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_material_lookup_provider.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/data/coldigom_praise_cache_warmup.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/leaflet/presentation/providers/leaflet_actions_provider.dart';
import 'package:coldigui/features/offline/data/datasources/favorite_pdf_ids_resolver.dart';
import 'package:coldigui/features/offline/data/providers/offline_core_providers.dart';
import 'package:coldigui/features/offline/domain/entities/local_pdf_source.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/offline/domain/usecases/fetch_and_store_pdf.dart';
import 'package:coldigui/features/offline/domain/usecases/resolve_pdf_for_reader.dart';
import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_actions_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';
import '../../../helpers/louvores_manifest_test_helpers.dart';

/// Repositório PDF nunca chamado — [_FixedResolvePdfForReader] ignora os
/// campos herdados e retorna [_source] direto em [call].
class _StubOfflinePdfRepository implements OfflinePdfRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubFetchAndStorePdf extends FetchAndStorePdf {
  _StubFetchAndStorePdf()
    : super(
        PdfBytesDatasource(Dio()),
        _StubOfflinePdfRepository(),
        favoritePdfIdsResolver: FavoritePdfIdsResolver.testing(),
      );
}

/// Resolver fixo — sempre retorna [_source], sem tocar rede/Isar.
class _FixedResolvePdfForReader extends ResolvePdfForReader {
  _FixedResolvePdfForReader(this._source)
    : super(_StubOfflinePdfRepository(), _StubFetchAndStorePdf());

  final LocalPdfSource _source;

  @override
  Future<LocalPdfSource> call({
    required String pdfId,
    required String remotePath,
    ProgressCallback? onProgress,
  }) async => _source;
}

void main() {
  const r2Key = 'assets/praises/p1/m1.chord';

  test('rótulo do folheto resolve cifra pelo lookup', () {
    final chordId = encodePdfId(r2Key);
    final labelOf = leafletLabelOf(
      CatalogMaterialLookup(
        chordsById: {
          chordId: ChordMaterial(
            chordId: chordId,
            r2Key: r2Key,
            nome: 'Comigo habita',
            numero: '692',
            groupId: 'p1',
            categoria: 'Cifra I',
            classificacao: 'Cancao',
          ),
        },
      ),
    );

    expect(labelOf(chordId)?.nome, 'Comigo habita');
    expect(labelOf(chordId)?.numero, '692');
    expect(labelOf('sem-hit'), isNull);
  });

  group('navigateToPdfId', () {
    test('id de cifra no cache retorna rota /cifra', () async {
      final chordId = encodePdfId(r2Key);
      final chord = ChordMaterial(
        chordId: chordId,
        r2Key: r2Key,
        nome: 'Comigo habita',
        numero: '692',
        groupId: 'p1',
        categoria: 'Cifra I',
        classificacao: 'Cancao',
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(coldigomChordMaterialsCacheProvider.notifier).mergeChords([
        chord,
      ]);

      final location = await container
          .read(readerCarouselActionsProvider.notifier)
          .navigateToPdfId(targetPdfId: chordId);

      expect(location, isNotNull);
      expect(location, startsWith(RoutePaths.chords));
      expect(location, contains('pdfId=$chordId'));
      expect(location, contains('titulo=Comigo'));
    });

    test(
      'id de cifra ausente do cache retorna null, não crasha nem vira /leitor',
      () async {
        final chordId = encodePdfId('assets/praises/p1/inexistente.chord');

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final location = await container
            .read(readerCarouselActionsProvider.notifier)
            .navigateToPdfId(targetPdfId: chordId);

        expect(location, isNull);
      },
    );

    test(
      'id de PDF segue o caminho existente de resolução e abertura',
      () async {
        const relPath = 'assets/praises/p1/m1.pdf';
        final pdfId = encodePdfId(relPath);
        final louvor = Louvor.fromManifest(
          nome: 'Comigo habita',
          numero: '692',
          categoria: 'Partitura',
          classificacao: 'Cancao',
          pdf: 'm1.pdf',
          pdfId: pdfId,
        );
        final source = LocalPdfSource(
          pdfId: pdfId,
          absolutePath: '/tmp/$pdfId.pdf',
          fromCache: true,
        );

        final container = ProviderContainer(
          overrides: [
            louvoresManifestOverride(LouvoresManifest.fromLouvores([louvor])),
            coldigomLouvoresOverride([louvor]),
            ensureColdigomPraiseMaterialsCachedProvider.overrideWithValue(
              (Louvor _) async {},
            ),
            resolvePdfForReaderProvider.overrideWithValue(
              _FixedResolvePdfForReader(source),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(louvoresManifestProvider.future);

        final location = await container
            .read(readerCarouselActionsProvider.notifier)
            .navigateToPdfId(targetPdfId: pdfId);

        expect(location, isNotNull);
        expect(location, startsWith(RoutePaths.reader));
        expect(location, contains('pdfId=$pdfId'));
        expect(location, contains('titulo=Comigo'));
      },
    );

    test('louvor só no cache Coldigom resolve pelo lookup', () async {
      const relPath = 'assets/praises/p9/coldigom.pdf';
      final pdfId = encodePdfId(relPath);
      final louvor = Louvor.fromManifest(
        nome: 'Só no Coldigom',
        numero: '900',
        categoria: 'Partitura',
        classificacao: 'Cancao',
        pdf: 'coldigom.pdf',
        pdfId: pdfId,
      );
      final source = LocalPdfSource(
        pdfId: pdfId,
        absolutePath: '/tmp/$pdfId.pdf',
        fromCache: true,
      );

      final container = ProviderContainer(
        overrides: [
          // Manifest PLPCG vazio: o id só existe no cache Coldigom.
          louvoresManifestOverride(LouvoresManifest.fromLouvores(const [])),
          ensureColdigomPraiseMaterialsCachedProvider.overrideWithValue(
            (Louvor _) async {},
          ),
          resolvePdfForReaderProvider.overrideWithValue(
            _FixedResolvePdfForReader(source),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(louvoresManifestProvider.future);
      container.read(coldigomLouvoresCacheProvider.notifier).mergeLouvores([
        louvor,
      ]);

      final location = await container
          .read(readerCarouselActionsProvider.notifier)
          .navigateToPdfId(targetPdfId: pdfId);

      expect(location, isNotNull);
      expect(location, startsWith(RoutePaths.reader));
      expect(location, contains('pdfId=$pdfId'));
    });
  });
}
