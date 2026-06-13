import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:coldigui/core/constants/offline_config.dart';
import 'package:coldigui/core/database/collections/louvor_cache.dart';
import 'package:coldigui/core/database/collections/offline_pdf_index.dart';
import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/features/offline/data/datasources/disk_space_checker.dart';
import 'package:coldigui/features/offline/data/datasources/favorite_pdf_ids_resolver.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/domain/exceptions/offline_bulk_exceptions.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/usecases/fetch_and_store_pdf.dart';
import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

String _encodePdfId(String path) {
  return base64Url
      .encode(utf8.encode(path))
      .replaceAll('+', '-')
      .replaceAll('/', '_')
      .replaceAll('=', '');
}

class _FakePdfBytesDatasource extends PdfBytesDatasource {
  _FakePdfBytesDatasource({
    required this.onFetch,
    Dio? dio,
  }) : super(dio ?? Dio());

  final Future<Uint8List> Function(
    String filePath, {
    ProgressCallback? onReceiveProgress,
  }) onFetch;
  int callCount = 0;

  @override
  Future<Uint8List> fetchBytes(
    String filePath, {
    ProgressCallback? onReceiveProgress,
  }) async {
    callCount++;
    return onFetch(filePath, onReceiveProgress: onReceiveProgress);
  }
}

class _FakeDiskSpaceChecker extends DiskSpaceChecker {
  _FakeDiskSpaceChecker(this._freeBytes);

  final int? _freeBytes;

  @override
  Future<int?> getFreeBytes() async => _freeBytes;
}

void main() {
  late Directory tempDir;
  late Directory docsDir;
  late Isar isar;
  late PdfLocalStore store;
  late OfflinePdfRepositoryImpl repository;
  late FavoritePdfIdsResolver favoritePdfIdsResolver;

  const relPath = 'ColAdultos/001.pdf';
  const remotePath = '/assets/ColAdultos/001.pdf';
  late String pdfId;

  final pdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    pdfId = _encodePdfId(relPath);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fetch_and_store_');
    docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);

    isar = await Isar.open(
      [LouvorCacheSchema, OfflinePdfIndexSchema, PlaylistSchema],
      directory: tempDir.path,
    );

    store = PdfLocalStore(
      getApplicationDocumentsDirectory: () async => docsDir,
    );
    repository = OfflinePdfRepositoryImpl(
      store: store,
      local: OfflinePdfLocalDatasource(isar),
    );
    favoritePdfIdsResolver =
        FavoritePdfIdsResolver(PlaylistLocalDatasource(isar));
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  FetchAndStorePdf createUseCase(
    _FakePdfBytesDatasource datasource, {
    int? freeBytes = 999999999,
    FavoritePdfIdsResolver? favoritesResolver,
    int cacheQuotaBytes = OfflineConfig.defaultPdfCacheQuotaBytes,
  }) {
    return FetchAndStorePdf(
      datasource,
      repository,
      diskSpaceChecker: _FakeDiskSpaceChecker(freeBytes),
      favoritePdfIdsResolver: favoritesResolver ?? favoritePdfIdsResolver,
      cacheQuotaBytes: cacheQuotaBytes,
    );
  }

  test('download + upsert feliz retorna fromCache false', () async {
    final datasource = _FakePdfBytesDatasource(
      onFetch: (_, {onReceiveProgress}) async => pdfBytes,
    );
    final useCase = createUseCase(datasource);

    final source = await useCase(
      pdfId: pdfId,
      remotePath: remotePath,
    );

    expect(source.fromCache, isFalse);
    expect(source.pdfId, pdfId);
    expect(await File(source.absolutePath).exists(), isTrue);
    expect(source.absolutePath, endsWith('ColAdultos/001.pdf'));

    final index =
        await isar.offlinePdfIndexs.filter().pdfIdEqualTo(pdfId).findFirst();
    expect(index, isNotNull);
    expect(index!.fileSize, pdfBytes.length);
    expect(datasource.callCount, 1);
  });

  test('category derivada quando null', () async {
    final datasource = _FakePdfBytesDatasource(
      onFetch: (_, {onReceiveProgress}) async => pdfBytes,
    );
    final useCase = createUseCase(datasource);

    await useCase(pdfId: pdfId, remotePath: remotePath);

    final index =
        await isar.offlinePdfIndexs.filter().pdfIdEqualTo(pdfId).findFirst();
    expect(index!.category, 'ColAdultos');
  });

  test('category explícita não deriva', () async {
    const explicitCategory = 'ColJovens';
    final datasource = _FakePdfBytesDatasource(
      onFetch: (_, {onReceiveProgress}) async => pdfBytes,
    );
    final useCase = createUseCase(datasource);

    await useCase(
      pdfId: pdfId,
      remotePath: remotePath,
      category: explicitCategory,
    );

    final index =
        await isar.offlinePdfIndexs.filter().pdfIdEqualTo(pdfId).findFirst();
    expect(index!.category, explicitCategory);
  });

  test('retry: falha rede na 1ª tentativa e sucesso na 2ª', () async {
    var attempts = 0;
    final datasource = _FakePdfBytesDatasource(
      onFetch: (_, {onReceiveProgress}) async {
        attempts++;
        if (attempts == 1) {
          throw DioException.connectionError(
            requestOptions: RequestOptions(path: remotePath),
            reason: 'timeout',
          );
        }
        return pdfBytes;
      },
    );
    final useCase = createUseCase(datasource);

    await useCase(pdfId: pdfId, remotePath: remotePath);

    expect(datasource.callCount, 2);
    expect(await repository.lookup(pdfId), isNotNull);
  });

  test('retryDelayForAttempt dobra a cada tentativa com jitter até 30%', () {
    final random = Random(42);
    final first = retryDelayForAttempt(1, random);
    final second = retryDelayForAttempt(2, random);

    expect(
      first.inMicroseconds,
      inInclusiveRange(
        OfflineConfig.retryBackoffBase.inMicroseconds,
        (OfflineConfig.retryBackoffBase * 1.3).inMicroseconds,
      ),
    );
    expect(
      second.inMicroseconds,
      inInclusiveRange(
        (OfflineConfig.retryBackoffBase * 2).inMicroseconds,
        (OfflineConfig.retryBackoffBase * 2 * 1.3).inMicroseconds,
      ),
    );
    expect(second.inMicroseconds, greaterThan(first.inMicroseconds));
  });

  test('retryDelayForAttempt respeita maxRetryDelay', () {
    final random = Random(0);
    final delay = retryDelayForAttempt(20, random);

    expect(delay, OfflineConfig.maxRetryDelay);
  });

  test('retry esgotado propaga DioException após maxRetryAttempts', () async {
    final datasource = _FakePdfBytesDatasource(
      onFetch: (_, {onReceiveProgress}) async {
        throw DioException.connectionError(
          requestOptions: RequestOptions(path: remotePath),
          reason: 'offline',
        );
      },
    );
    final useCase = createUseCase(datasource);

    await expectLater(
      useCase(pdfId: pdfId, remotePath: remotePath),
      throwsA(isA<DioException>()),
    );
    expect(datasource.callCount, OfflineConfig.maxRetryAttempts);
    expect(await repository.lookup(pdfId), isNull);
  });

  test('HTTP 404 falha imediatamente sem retry', () async {
    final datasource = _FakePdfBytesDatasource(
      onFetch: (_, {onReceiveProgress}) async {
        throw DioException.badResponse(
          statusCode: 404,
          requestOptions: RequestOptions(path: remotePath),
          response: Response(
            requestOptions: RequestOptions(path: remotePath),
            statusCode: 404,
          ),
        );
      },
    );
    final useCase = createUseCase(datasource);

    await expectLater(
      useCase(pdfId: pdfId, remotePath: remotePath),
      throwsA(isA<DioException>()),
    );
    expect(datasource.callCount, 1);
  });

  test('resposta vazia propaga Exception sem retry', () async {
    final datasource = _FakePdfBytesDatasource(
      onFetch: (_, {onReceiveProgress}) async {
        throw Exception('Resposta PDF vazia');
      },
    );
    final useCase = createUseCase(datasource);

    await expectLater(
      useCase(pdfId: pdfId, remotePath: remotePath),
      throwsA(isA<Exception>()),
    );
    expect(datasource.callCount, 1);
  });

  test('repassa onProgress ao datasource remoto', () async {
    ProgressCallback? captured;
    final datasource = _FakePdfBytesDatasource(
      onFetch: (_, {onReceiveProgress}) async {
        captured = onReceiveProgress;
        return pdfBytes;
      },
    );
    final useCase = createUseCase(datasource);

    await useCase(
      pdfId: pdfId,
      remotePath: remotePath,
      onProgress: (_, __) {},
    );

    expect(captured, isNotNull);
  });

  test('espaço livre insuficiente lança InsufficientDiskSpaceException',
      () async {
    final datasource = _FakePdfBytesDatasource(
      onFetch: (_, {onReceiveProgress}) async => pdfBytes,
    );
    final useCase = createUseCase(datasource, freeBytes: 1024);

    await expectLater(
      useCase(pdfId: pdfId, remotePath: remotePath),
      throwsA(isA<InsufficientDiskSpaceException>()),
    );
    expect(await repository.lookup(pdfId), isNull);
  });

  test('evict LRU quando quota seria excedida', () async {
    final oldId = _encodePdfId('ColAdultos/old.pdf');
    final newId = _encodePdfId('ColAdultos/new.pdf');

    await repository.upsert(
      pdfId: oldId,
      bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 1, 2, 3, 4]),
      category: 'ColAdultos',
    );

    final datasource = _FakePdfBytesDatasource(
      onFetch: (_, {onReceiveProgress}) async =>
          Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 5, 6, 7]),
    );

    final useCase = createUseCase(
      datasource,
      cacheQuotaBytes: 12,
    );

    await useCase(
      pdfId: newId,
      remotePath: '/assets/ColAdultos/new.pdf',
    );

    expect(await repository.lookup(oldId), isNull);
    expect(await repository.lookup(newId), isNotNull);
    expect(await repository.totalCachedBytes(), lessThanOrEqualTo(12));
  });
}
