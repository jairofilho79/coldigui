import 'dart:async';

import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/coldigom/data/coldigom_praise_cache_warmup.dart';
import 'package:coldigui/features/offline/data/datasources/favorite_pdf_ids_resolver.dart';
import 'package:coldigui/features/offline/data/providers/offline_core_providers.dart';
import 'package:coldigui/features/offline/domain/entities/local_pdf_source.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/offline/domain/usecases/fetch_and_store_pdf.dart';
import 'package:coldigui/features/offline/domain/usecases/resolve_pdf_for_reader.dart';
import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_actions_provider.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

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

/// Resolver fixo — sempre retorna [_source], sem tocar rede/Isar. Guarda os
/// `pdfId` recebidos para o teste conferir a chave de armazenamento.
class _FixedResolvePdfForReader extends ResolvePdfForReader {
  _FixedResolvePdfForReader(this._source)
    : super(_StubOfflinePdfRepository(), _StubFetchAndStorePdf());

  final LocalPdfSource _source;
  final resolvedPdfIds = <String>[];

  @override
  Future<LocalPdfSource> call({
    required String pdfId,
    required String remotePath,
    ProgressCallback? onProgress,
  }) async {
    resolvedPdfIds.add(pdfId);
    return _source;
  }
}

void main() {
  const relPath = 'assets/praises/p1/m1.pdf';
  final pdfId = encodePdfId(relPath);
  final louvor = Louvor.fromManifest(
    nome: 'Comigo habita',
    numero: '692',
    categoria: 'Partitura',
    classificacao: 'Balada',
    pdf: 'm1.pdf',
    pdfId: pdfId,
  );
  const source = LocalPdfSource(
    pdfId: 'p1',
    absolutePath: '/tmp/comigo-habita.pdf',
    fromCache: true,
  );

  group('navigateToPdfId — warmup Coldigom nunca bloqueia nem impede', () {
    test('warmup que nunca completa não atrasa a troca de louvor', () {
      fakeAsync((async) {
        final logs = <String>[];
        final originalDebugPrint = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          logs.add(message ?? '');
        };
        addTearDown(() => debugPrint = originalDebugPrint);

        final neverCompletes = Completer<void>();
        final container = ProviderContainer(
          overrides: [
            coldigomLouvoresOverride([louvor]),
            ensureColdigomPraiseMaterialsCachedProvider.overrideWithValue(
              // O timeout mora dentro do provider real; a versão de teste o
              // reproduz para o "nunca completa" virar falha registrada.
              (Louvor _) =>
                  neverCompletes.future.timeout(coldigomWarmupDefaultTimeout),
            ),
            resolvePdfForReaderProvider.overrideWithValue(
              _FixedResolvePdfForReader(source),
            ),
          ],
        );
        addTearDown(container.dispose);

        async.elapse(Duration.zero);

        String? location;
        unawaited(
          container
              .read(readerCarouselActionsProvider.notifier)
              .navigateToPdfId(targetPdfId: pdfId)
              .then((value) => location = value),
        );

        // Flush microtasks/futures síncronos sem avançar o timeout de 5s.
        async.elapse(Duration.zero);

        expect(
          location,
          isNotNull,
          reason: 'não deve esperar o warmup (que nunca completa) para navegar',
        );
        expect(location, startsWith(RoutePaths.reader));

        // Avança além do timeout — o warmup interno deve falhar em silêncio.
        async.elapse(const Duration(seconds: 6));
        expect(logs.any((l) => l.contains('[coldigom] warmup falhou')), isTrue);
      });
    });

    test('warmup que lança de imediato não impede a troca de louvor', () async {
      final logs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        logs.add(message ?? '');
      };
      addTearDown(() => debugPrint = originalDebugPrint);

      final container = ProviderContainer(
        overrides: [
          coldigomLouvoresOverride([louvor]),
          ensureColdigomPraiseMaterialsCachedProvider.overrideWithValue(
            (Louvor _) async => throw StateError('coldigom indisponível'),
          ),
          resolvePdfForReaderProvider.overrideWithValue(
            _FixedResolvePdfForReader(source),
          ),
        ],
      );
      addTearDown(container.dispose);

      final location = await container
          .read(readerCarouselActionsProvider.notifier)
          .navigateToPdfId(targetPdfId: pdfId);

      expect(location, isNotNull);
      expect(location, startsWith(RoutePaths.reader));
      // Dá uma volta de event loop para o unawaited catchError rodar.
      await Future<void>.delayed(Duration.zero);
      expect(logs.any((l) => l.contains('[coldigom] warmup falhou')), isTrue);
    });
  });

  group('navigateToKey — foca a ocorrência e resolve a rota', () {
    const otherPath = 'assets/praises/p2/m1.pdf';
    final otherPdfId = encodePdfId(otherPath);
    final other = Louvor.fromManifest(
      nome: 'Outro louvor',
      numero: '1',
      categoria: 'Partitura',
      classificacao: 'Balada',
      pdf: 'm1.pdf',
      pdfId: otherPdfId,
    );

    CarouselItem item(String materialId, int index, {String? key}) {
      return CarouselItem(
        materialId: materialId,
        kind: MaterialKind.pdf,
        index: index,
        key: key ?? materialId,
        numero: '1',
        nome: 'Louvor',
        categoria: 'Partitura',
        classificacao: 'Balada',
      );
    }

    Future<ProviderContainer> boot(List<CarouselItem> items) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          carouselItemsProvider.overrideWithValue(items),
          coldigomLouvoresOverride([louvor, other]),
          ensureColdigomPraiseMaterialsCachedProvider.overrideWithValue(
            (Louvor _) async {},
          ),
          resolvePdfForReaderProvider.overrideWithValue(
            _FixedResolvePdfForReader(source),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('a segunda ocorrência vira o item focado', () async {
      final container = await boot([
        item(pdfId, 0),
        item(otherPdfId, 1),
        item(pdfId, 2, key: '$pdfId#1'),
      ]);

      final location = await container
          .read(readerCarouselActionsProvider.notifier)
          .navigateToKey(key: '$pdfId#1');

      expect(location, isNotNull);
      expect(location, startsWith(RoutePaths.reader));
      expect(location, contains('pdfId=$pdfId'));
      expect(container.read(carouselFocusedKeyProvider), '$pdfId#1');
      expect(container.read(carouselFocusedIndexProvider), 2);
    });

    test('chave que não está na face não navega nem troca o foco', () async {
      final container = await boot([item(pdfId, 0)]);

      final location = await container
          .read(readerCarouselActionsProvider.notifier)
          .navigateToKey(key: 'inexistente');

      expect(location, isNull);
      expect(container.read(carouselFocusedKeyProvider), isNull);
    });
  });
}
