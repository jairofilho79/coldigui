import 'dart:convert';

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
import 'package:coldigui/features/pdf_reader/domain/ports/prefetch_network_policy.dart';
import 'package:coldigui/features/pdf_reader/domain/usecases/prefetch_adjacent_carousel_pdfs.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _AllowPolicy implements PrefetchNetworkPolicy {
  @override
  Future<bool> allowsAdjacentPdfPrefetch() async => true;
}

class _DenyPolicy implements PrefetchNetworkPolicy {
  @override
  Future<bool> allowsAdjacentPdfPrefetch() async => false;
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
    return super.noSuchMethod(invocation);
  }
}

class _TrackingFetchAndStore extends FetchAndStorePdf {
  _TrackingFetchAndStore(this.resolvedPdfIds)
      : super(
          _UnusedBytesDatasource(),
          _UnusedRepo(),
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
  }) async {
    resolvedPdfIds.add(pdfId);
    return LocalPdfSource(
      pdfId: pdfId,
      absolutePath: '/tmp/$pdfId.pdf',
      fromCache: false,
    );
  }
}

class _UnusedBytesDatasource extends PdfBytesDatasource {
  _UnusedBytesDatasource() : super(Dio());
}

class _UnusedDiskSpaceChecker extends DiskSpaceChecker {
  @override
  Future<int?> getFreeBytes() async => 999999999;
}

class _UnusedRepo implements OfflinePdfRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #totalCachedBytes) {
      return Future<int>.value(0);
    }
    if (invocation.memberName == #evictOldestPdfs) {
      return Future<int>.value(0);
    }
    return super.noSuchMethod(invocation);
  }
}

String _pdfIdForPath(String relPath) {
  return base64Url
      .encode(utf8.encode(relPath))
      .replaceAll('+', '-')
      .replaceAll('/', '_')
      .replaceAll('=', '');
}

Louvor _louvor(String relPath, {String nome = 'Louvor'}) {
  return Louvor.fromManifest(
    nome: nome,
    numero: '1',
    categoria: 'Partitura',
    classificacao: 'ColAdultos',
    pdf: relPath.split('/').last,
    pdfId: _pdfIdForPath(relPath),
  );
}

void main() {
  final prevId = _pdfIdForPath('assets/ColAdultos/prev.pdf');
  final currentId = _pdfIdForPath('assets/ColAdultos/current.pdf');
  final nextId = _pdfIdForPath('assets/ColAdultos/next.pdf');

  group('PrefetchAdjacentCarouselPdfs', () {
    test('prefetch resolve vizinhos não cacheados em WiFi', () async {
      final resolved = <String>[];
      final repository = _FakeOfflineRepository(cachedPdfIds: {currentId});
      final useCase = PrefetchAdjacentCarouselPdfs(
        validateAvailability: ValidatePdfAvailability(repository),
        resolvePdf: ResolvePdfForReader(
          repository,
          _TrackingFetchAndStore(resolved),
        ),
        networkPolicy: _AllowPolicy(),
      );

      await useCase(
        catalog: [
          _louvor('assets/ColAdultos/prev.pdf'),
          _louvor('assets/ColAdultos/current.pdf'),
          _louvor('assets/ColAdultos/next.pdf'),
        ],
        previousPdfId: prevId,
        nextPdfId: nextId,
      );

      expect(resolved, [prevId, nextId]);
    });

    test('pula vizinhos já cacheados', () async {
      final resolved = <String>[];
      final repository =
          _FakeOfflineRepository(cachedPdfIds: {prevId, currentId});
      final useCase = PrefetchAdjacentCarouselPdfs(
        validateAvailability: ValidatePdfAvailability(repository),
        resolvePdf: ResolvePdfForReader(
          repository,
          _TrackingFetchAndStore(resolved),
        ),
        networkPolicy: _AllowPolicy(),
      );

      await useCase(
        catalog: [
          _louvor('assets/ColAdultos/prev.pdf'),
          _louvor('assets/ColAdultos/current.pdf'),
          _louvor('assets/ColAdultos/next.pdf'),
        ],
        previousPdfId: prevId,
        nextPdfId: nextId,
      );

      expect(resolved, [nextId]);
    });

    test('não prefetch em dados móveis', () async {
      final resolved = <String>[];
      final repository = _FakeOfflineRepository(cachedPdfIds: {});
      final useCase = PrefetchAdjacentCarouselPdfs(
        validateAvailability: ValidatePdfAvailability(repository),
        resolvePdf: ResolvePdfForReader(
          repository,
          _TrackingFetchAndStore(resolved),
        ),
        networkPolicy: _DenyPolicy(),
      );

      await useCase(
        catalog: [
          _louvor('assets/ColAdultos/prev.pdf'),
          _louvor('assets/ColAdultos/current.pdf'),
          _louvor('assets/ColAdultos/next.pdf'),
        ],
        previousPdfId: prevId,
        nextPdfId: nextId,
      );

      expect(resolved, isEmpty);
    });

    test('ignora pdfId órfão no catálogo', () async {
      final resolved = <String>[];
      final repository = _FakeOfflineRepository(cachedPdfIds: {});
      final useCase = PrefetchAdjacentCarouselPdfs(
        validateAvailability: ValidatePdfAvailability(repository),
        resolvePdf: ResolvePdfForReader(
          repository,
          _TrackingFetchAndStore(resolved),
        ),
        networkPolicy: _AllowPolicy(),
      );

      await useCase(
        catalog: [_louvor('assets/ColAdultos/current.pdf')],
        previousPdfId: _pdfIdForPath('assets/ColAdultos/missing.pdf'),
        nextPdfId: null,
      );

      expect(resolved, isEmpty);
    });
  });
}
