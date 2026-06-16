import 'dart:async';
import 'dart:convert';

import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/offline/data/datasources/disk_space_checker.dart';
import 'package:coldigui/features/offline/data/datasources/favorite_pdf_ids_resolver.dart';
import 'package:coldigui/features/offline/domain/entities/local_pdf_source.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_entry.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/offline/domain/usecases/fetch_and_store_pdf.dart';
import 'package:coldigui/features/offline/domain/usecases/resolve_pdf_for_reader.dart';
import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:coldigui/features/pdf_opening/domain/usecases/validate_pdf_availability.dart';
import 'package:coldigui/features/pdf_reader/data/adapters/pdfx_viewer_adapter.dart';
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
import 'package:pdfx/pdfx.dart';

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
          diskSpaceChecker: _UnusedDiskSpaceChecker(),
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

class _UnusedDiskSpaceChecker extends DiskSpaceChecker {
  @override
  Future<int?> getFreeBytes() async => 999999999;
}

class _SessionTestAdapter extends PdfxViewerAdapter {
  _SessionTestAdapter()
      : super(
          _NoOpBytesDatasource(),
          resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
        );

  @override
  Future<PdfControllerPinch> openDocument(String filePath) async {
    return PdfControllerPinch(document: Completer<PdfDocument>().future);
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

CarouselItem _carouselItem(String relPath, int sortOrder) {
  final pdfId = _pdfIdForPath(relPath);
  return CarouselItem(
    pdfId: pdfId,
    sortOrder: sortOrder,
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
  final prevPdfId = _pdfIdForPath(prevPath);
  final nextPdfId = _pdfIdForPath(nextPath);

  test('prefetch dispara após sessão carregar sem bloquear abertura', () async {
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
        pdfxViewerAdapterProvider.overrideWithValue(_SessionTestAdapter()),
        prefetchNetworkPolicyProvider.overrideWithValue(_AllowPolicy()),
        prefetchAdjacentCarouselPdfsProvider.overrideWithValue(prefetch),
        prefetchLouvorCatalogProvider.overrideWith((ref) => [
              _louvor(prevPath),
              _louvor(currentPath),
              _louvor(nextPath),
            ]),
        carouselLouvoresProvider.overrideWith(
          () => _FixedCarouselNotifier([
            _carouselItem(prevPath, 0),
            _carouselItem(currentPath, 1),
            _carouselItem(nextPath, 2),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final sessionSub = container.listen(
      pdfReaderSessionProvider(filePath),
      (_, __) {},
      fireImmediately: true,
    );
    final prefetchSub = container.listen(
      readerAdjacentPdfPrefetchProvider(
        ReaderAdjacentPdfPrefetchParams(
          filePath: filePath,
          pdfId: currentPdfId,
        ),
      ),
      (_, __) {},
      fireImmediately: true,
    );

    await container.read(pdfReaderSessionProvider(filePath).future);
    expect(resolved, isEmpty);

    await Future<void>.delayed(Duration.zero);
    expect(resolved, [prevPdfId, nextPdfId]);

    prefetchSub.close();
    sessionSub.close();
  });
}

class _FixedCarouselNotifier extends CarouselLouvoresNotifier {
  _FixedCarouselNotifier(this._items);

  final List<CarouselItem> _items;

  @override
  List<CarouselItem> build() => _items;
}
