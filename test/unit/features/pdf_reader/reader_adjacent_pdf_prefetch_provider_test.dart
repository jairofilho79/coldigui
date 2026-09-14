import 'dart:convert';

import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/offline/data/datasources/favorite_pdf_ids_resolver.dart';
import 'package:coldigui/features/offline/domain/entities/local_pdf_source.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_entry.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/offline/domain/usecases/fetch_and_store_pdf.dart';
import 'package:coldigui/features/offline/domain/usecases/resolve_pdf_for_reader.dart';
import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:coldigui/features/pdf_opening/domain/usecases/validate_pdf_availability.dart';
import 'package:coldigui/features/pdf_reader/data/adapters/pdfrx_viewer_adapter.dart';
import 'package:coldigui/features/pdf_reader/data/models/pdf_reader_viewer_handle.dart';
import 'package:coldigui/features/pdf_reader/data/providers/pdf_reader_prefetch_providers.dart';
import 'package:coldigui/features/pdf_reader/data/providers/pdf_reader_providers.dart';
import 'package:coldigui/features/pdf_reader/data/utils/pdf_source_resolver.dart';
import 'package:coldigui/features/pdf_reader/domain/ports/prefetch_network_policy.dart';
import 'package:coldigui/features/pdf_reader/domain/usecases/prefetch_adjacent_carousel_pdfs.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_adjacent_pdf_prefetch_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pdf_reader_test_helpers.dart';

class _AllowPolicy implements PrefetchNetworkPolicy {
  @override
  Future<bool> allowsAdjacentPdfPrefetch() async => true;
}

class _FakeOfflineRepository implements OfflinePdfRepository {
  _FakeOfflineRepository({required this.cachedPdfIds});

  final Set<String> cachedPdfIds;

  OfflinePdfEntry _entry(String pdfId) {
    return OfflinePdfEntry(
      pdfId: pdfId,
      absolutePath: '/tmp/$pdfId.pdf',
      category: 'ColAdultos',
      fileSize: 100,
      downloadedAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #lookup ||
        invocation.memberName == #lookupWithIndexState) {
      final pdfId = invocation.positionalArguments[0] as String;
      if (cachedPdfIds.contains(pdfId)) {
        final entry = _entry(pdfId);
        if (invocation.memberName == #lookup) {
          return Future<OfflinePdfEntry?>.value(entry);
        }
        return Future<(OfflinePdfEntry?, bool)>.value((entry, true));
      }
      if (invocation.memberName == #lookup) {
        return Future<OfflinePdfEntry?>.value(null);
      }
      return Future<(OfflinePdfEntry?, bool)>.value((null, false));
    }
    if (invocation.memberName == #totalCachedBytes) {
      return Future<int>.value(0);
    }
    if (invocation.memberName == #evictOldestPdfs) {
      return Future<int>.value(0);
    }
    if (invocation.memberName == #flushPendingTouchLastAccessed) {
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _TrackingFetchAndStore extends FetchAndStorePdf {
  _TrackingFetchAndStore(this.resolvedPdfIds)
    : super(
        _NoOpBytesDatasource(),
        _FakeOfflineRepository(cachedPdfIds: {}),
        favoritePdfIdsResolver: FavoritePdfIdsResolver.testing(),
      );

  final List<String> resolvedPdfIds;

  @override
  Future<LocalPdfSource> call({
    required String pdfId,
    required String remotePath,
    String? category,
    ProgressCallback? onProgress,
    bool persistentDownload = false,
    CancelToken? cancelToken,
  }) async {
    resolvedPdfIds.add(pdfId);
    return LocalPdfSource(
      pdfId: pdfId,
      absolutePath: '/tmp/$pdfId.pdf',
      fromCache: false,
    );
  }
}

class _NoOpBytesDatasource extends PdfBytesDatasource {
  _NoOpBytesDatasource()
    : super(
        Dio(),
        resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
      );
}

class _SessionTestAdapter extends PdfrxViewerAdapter {
  _SessionTestAdapter()
    : super(
        _NoOpBytesDatasource(),
        resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
      );

  @override
  Future<PdfReaderViewerHandle> openDocument(String filePath) async {
    return createTrackableHandle();
  }
}

String _pdfIdForPath(String relPath) {
  return base64Url
      .encode(utf8.encode(relPath))
      .replaceAll('+', '-')
      .replaceAll('/', '_')
      .replaceAll('=', '');
}

Louvor _louvor(String relPath) {
  return Louvor.fromManifest(
    nome: 'Louvor $relPath',
    numero: '1',
    categoria: 'Partitura',
    classificacao: 'ColAdultos',
    pdf: relPath.split('/').last,
    pdfId: _pdfIdForPath(relPath),
  );
}

CarouselItem _carouselItem(String relPath, int index, {String? key}) {
  final materialId = _pdfIdForPath(relPath);
  return CarouselItem(
    materialId: materialId,
    kind: MaterialKind.pdf,
    index: index,
    key: key ?? materialId,
    numero: '1',
    nome: 'Louvor $relPath',
    categoria: 'ColAdultos',
    classificacao: 'ColAdultos',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const filePath = 'asset:fixtures/sample.pdf';
  final prevPath = 'assets/ColAdultos/prev.pdf';
  final currentPath = 'assets/ColAdultos/current.pdf';
  final nextPath = 'assets/ColAdultos/next.pdf';
  final currentPdfId = _pdfIdForPath(currentPath);
  final prevId = _pdfIdForPath(prevPath);
  final nextId = _pdfIdForPath(nextPath);

  test('prefetch dispara após sessão carregar sem bloquear abertura', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final resolved = <String>[];
    final repository = _FakeOfflineRepository(cachedPdfIds: {currentPdfId});
    final fetch = _TrackingFetchAndStore(resolved);
    final prefetch = PrefetchAdjacentCarouselPdfs(
      validateAvailability: ValidatePdfAvailability(repository),
      resolvePdf: ResolvePdfForReader(repository, fetch),
      networkPolicy: _AllowPolicy(),
    );

    final container = ProviderContainer(
      overrides: [
        pdfViewerAdapterProvider.overrideWithValue(_SessionTestAdapter()),
        prefetchNetworkPolicyProvider.overrideWithValue(_AllowPolicy()),
        prefetchAdjacentCarouselPdfsProvider.overrideWithValue(prefetch),
        prefetchLouvorCatalogProvider.overrideWith(
          (ref) => [_louvor(prevPath), _louvor(currentPath), _louvor(nextPath)],
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        carouselItemsProvider.overrideWithValue([
          _carouselItem(prevPath, 0),
          _carouselItem(currentPath, 1),
          _carouselItem(nextPath, 2),
        ]),
      ],
    );
    addTearDown(container.dispose);

    final sessionSub = container.listen(
      pdfReaderSessionProvider(filePath),
      (_, _) {},
      fireImmediately: true,
    );
    final prefetchSub = container.listen(
      readerAdjacentPdfPrefetchProvider(
        ReaderAdjacentPdfPrefetchParams(
          filePath: filePath,
          pdfId: currentPdfId,
        ),
      ),
      (_, _) {},
      fireImmediately: true,
    );

    await container.read(pdfReaderSessionProvider(filePath).future);
    expect(resolved, isEmpty);

    await Future<void>.delayed(Duration.zero);
    expect(resolved, [prevId, nextId]);

    prefetchSub.close();
    sessionSub.close();
  });

  test('louvor repetido pré-busca os vizinhos da ocorrência focada', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final resolved = <String>[];
    final repository = _FakeOfflineRepository(cachedPdfIds: {currentPdfId});
    final fetch = _TrackingFetchAndStore(resolved);
    final prefetch = PrefetchAdjacentCarouselPdfs(
      validateAvailability: ValidatePdfAvailability(repository),
      resolvePdf: ResolvePdfForReader(repository, fetch),
      networkPolicy: _AllowPolicy(),
    );

    // Face: [prev, current, next, current#1] — a ocorrência focada é a
    // segunda do `current`, cujo único vizinho é o `next`.
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        pdfViewerAdapterProvider.overrideWithValue(_SessionTestAdapter()),
        prefetchNetworkPolicyProvider.overrideWithValue(_AllowPolicy()),
        prefetchAdjacentCarouselPdfsProvider.overrideWithValue(prefetch),
        prefetchLouvorCatalogProvider.overrideWith(
          (ref) => [_louvor(prevPath), _louvor(currentPath), _louvor(nextPath)],
        ),
        carouselItemsProvider.overrideWithValue([
          _carouselItem(prevPath, 0),
          _carouselItem(currentPath, 1),
          _carouselItem(nextPath, 2),
          _carouselItem(currentPath, 3, key: '$currentPdfId#1'),
        ]),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(carouselFocusedIndexProvider.notifier)
        .focusKey('$currentPdfId#1');

    final sessionSub = container.listen(
      pdfReaderSessionProvider(filePath),
      (_, _) {},
      fireImmediately: true,
    );
    final prefetchSub = container.listen(
      readerAdjacentPdfPrefetchProvider(
        ReaderAdjacentPdfPrefetchParams(
          filePath: filePath,
          pdfId: currentPdfId,
        ),
      ),
      (_, _) {},
      fireImmediately: true,
    );

    await container.read(pdfReaderSessionProvider(filePath).future);
    await Future<void>.delayed(Duration.zero);

    expect(resolved, [nextId]);

    prefetchSub.close();
    sessionSub.close();
  });
}
