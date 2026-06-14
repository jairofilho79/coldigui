import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:coldigui/core/constants/offline_config.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/datasources/zip_package_downloader.dart';
import 'package:coldigui/features/offline/data/utils/zip_pdf_extractor.dart';
import 'package:coldigui/features/offline/domain/exceptions/offline_bulk_exceptions.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late Directory docsDir;
  late PdfLocalStore store;
  late ZipPackageDownloader downloader;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zip_downloader_');
    docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);
    store = PdfLocalStore(
      getApplicationDocumentsDirectory: () async => docsDir,
    );
    downloader = ZipPackageDownloader(Dio(), store);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('cleanOrphanedTempFiles remove .tmp e preserva .zip', () async {
    final zipDir = Directory(
      '${docsDir.path}/${OfflineConfig.pdfStorageSubdir}/${OfflineConfig.zipTempSubdir}',
    );
    await zipDir.create(recursive: true);

    final tmpFile = File('${zipDir.path}/Partitura-1.zip.tmp');
    final zipFile = File('${zipDir.path}/Partitura-1.zip');
    await tmpFile.writeAsString('partial download');
    await zipFile.writeAsString('complete zip');

    await downloader.cleanOrphanedTempFiles();

    expect(await tmpFile.exists(), isFalse);
    expect(await zipFile.exists(), isTrue);
  });

  test('cleanOrphanedTempFiles é no-op quando diretório não existe', () async {
    await expectLater(downloader.cleanOrphanedTempFiles(), completes);
  });

  test('reutiliza ZIP cacheado quando tamanho coincide', () async {
    final zipBytes = await _createZipBytes();
    final zipDir = Directory(
      '${docsDir.path}/${OfflineConfig.pdfStorageSubdir}/${OfflineConfig.zipTempSubdir}',
    );
    await zipDir.create(recursive: true);
    final cached = File('${zipDir.path}/Partitura-1.zip');
    await cached.writeAsBytes(zipBytes);

    final path = await downloader.download(
      url: 'http://example.invalid/packages/Partitura-1.zip',
      filename: 'Partitura-1.zip',
      expectedSize: zipBytes.length,
    );

    expect(path, cached.path);
    expect(await cached.length(), zipBytes.length);
  });

  test('re-baixa quando tamanho cacheado diverge do manifest', () async {
    final zipBytes = await _createZipBytes();
    final zipDir = Directory(
      '${docsDir.path}/${OfflineConfig.pdfStorageSubdir}/${OfflineConfig.zipTempSubdir}',
    );
    await zipDir.create(recursive: true);
    final cached = File('${zipDir.path}/Partitura-1.zip');
    await cached.writeAsBytes(zipBytes.sublist(0, zipBytes.length ~/ 2));

    final dio = Dio();
    dio.httpClientAdapter = _FakeDownloadAdapter(zipBytes);

    final redownloader = ZipPackageDownloader(dio, store);
    final path = await redownloader.download(
      url: 'http://example.invalid/packages/Partitura-1.zip',
      filename: 'Partitura-1.zip',
      expectedSize: zipBytes.length,
    );

    expect(await File(path).length(), zipBytes.length);
  });

  test('retoma download parcial via HTTP Range (206)', () async {
    final zipBytes = await _createZipBytes();
    final zipDir = Directory(
      '${docsDir.path}/${OfflineConfig.pdfStorageSubdir}/${OfflineConfig.zipTempSubdir}',
    );
    await zipDir.create(recursive: true);

    final partial = zipBytes.length ~/ 2;
    final tmp = File('${zipDir.path}/Partitura-1.zip.tmp');
    await tmp.writeAsBytes(zipBytes.sublist(0, partial));

    final dio = Dio();
    final adapter = _FakeDownloadAdapter(
      zipBytes,
      acceptRanges: true,
    );
    dio.httpClientAdapter = adapter;

    final path = await ZipPackageDownloader(dio, store).download(
      url: 'http://example.invalid/packages/Partitura-1.zip',
      filename: 'Partitura-1.zip',
      expectedSize: zipBytes.length,
    );

    expect(await File(path).length(), zipBytes.length);
    expect(
      adapter.requests.any(
        (options) => options.method == 'HEAD',
      ),
      isTrue,
    );
    expect(
      adapter.requests.any(
        (options) => options.headers['Range'] == 'bytes=$partial-',
      ),
      isTrue,
    );
  });

  test('fallback para download completo quando Range retorna 200', () async {
    final zipBytes = await _createZipBytes();
    final zipDir = Directory(
      '${docsDir.path}/${OfflineConfig.pdfStorageSubdir}/${OfflineConfig.zipTempSubdir}',
    );
    await zipDir.create(recursive: true);

    final partial = zipBytes.length ~/ 2;
    final tmp = File('${zipDir.path}/Partitura-1.zip.tmp');
    await tmp.writeAsBytes(zipBytes.sublist(0, partial));

    final dio = Dio();
    final adapter = _FakeDownloadAdapter(
      zipBytes,
      acceptRanges: true,
      fullResponseOnRange: true,
    );
    dio.httpClientAdapter = adapter;

    final path = await ZipPackageDownloader(dio, store).download(
      url: 'http://example.invalid/packages/Partitura-1.zip',
      filename: 'Partitura-1.zip',
      expectedSize: zipBytes.length,
    );

    expect(await File(path).readAsBytes(), zipBytes);
  });

  test('rejeita ZIP final com tamanho divergente do manifest', () async {
    final zipBytes = await _createZipBytes();
    final dio = Dio();
    dio.httpClientAdapter = _FakeDownloadAdapter(
      zipBytes.sublist(0, zipBytes.length - 1),
    );

    await expectLater(
      ZipPackageDownloader(dio, store).download(
        url: 'http://example.invalid/packages/Partitura-1.zip',
        filename: 'Partitura-1.zip',
        expectedSize: zipBytes.length,
      ),
      throwsA(isA<ZipDownloadSizeMismatchException>()),
    );

    final tmp = File(
      '${docsDir.path}/${OfflineConfig.pdfStorageSubdir}/${OfflineConfig.zipTempSubdir}/Partitura-1.zip.tmp',
    );
    expect(await tmp.exists(), isFalse);
  });

  test('passa receiveTimeout do OfflineConfig ao download', () async {
    final zipBytes = await _createZipBytes();
    RequestOptions? captured;

    final dio = Dio();
    dio.httpClientAdapter = _CapturingDownloadAdapter(
      bytes: zipBytes,
      onFetch: (options) => captured = options,
    );

    final capturingDownloader = ZipPackageDownloader(dio, store);
    await capturingDownloader.download(
      url: 'http://example.invalid/packages/Partitura-1.zip',
      filename: 'Partitura-1.zip',
    );

    expect(captured, isNotNull);
    expect(
      captured!.receiveTimeout,
      OfflineConfig.zipDownloadReceiveTimeout,
    );
    expect(captured!.sendTimeout, OfflineConfig.zipDownloadSendTimeout);
  });

  test('rejeita download com tamanho divergente do manifest', () async {
    final zipBytes = await _createZipBytes();
    final zipDir = Directory(
      '${docsDir.path}/${OfflineConfig.pdfStorageSubdir}/${OfflineConfig.zipTempSubdir}',
    );
    await zipDir.create(recursive: true);
    final target = File('${zipDir.path}/Partitura-1.zip');
    final tmp = File('${target.path}.tmp');

    final dio = Dio();
    dio.httpClientAdapter = _FakeDownloadAdapter(
      zipBytes.sublist(0, zipBytes.length ~/ 2),
    );

    final mismatchDownloader = ZipPackageDownloader(dio, store);

    await expectLater(
      mismatchDownloader.download(
        url: 'http://example.invalid/packages/Partitura-1.zip',
        filename: 'Partitura-1.zip',
        expectedSize: zipBytes.length,
      ),
      throwsA(isA<ZipDownloadSizeMismatchException>()),
    );

    expect(await target.exists(), isFalse);
    expect(await tmp.exists(), isFalse);
  });

  test('retry: receiveTimeout na 1ª tentativa e sucesso na 2ª', () async {
    final zipBytes = await _createZipBytes();
    final zipDir = Directory(
      '${docsDir.path}/${OfflineConfig.pdfStorageSubdir}/${OfflineConfig.zipTempSubdir}',
    );
    await zipDir.create(recursive: true);
    final target = File('${zipDir.path}/Partitura-1.zip');

    final dio = Dio();
    dio.httpClientAdapter = _RetryOnFirstTimeoutAdapter(zipBytes);

    final retryDownloader = ZipPackageDownloader(dio, store);
    final path = await retryDownloader.download(
      url: 'http://example.invalid/packages/Partitura-1.zip',
      filename: 'Partitura-1.zip',
      expectedSize: zipBytes.length,
    );

    expect(path, target.path);
    expect(await target.length(), zipBytes.length);
    expect(
      (dio.httpClientAdapter as _RetryOnFirstTimeoutAdapter).attempts,
      2,
    );
  });

  test('ZipDecoder lança mensagem informativa para ZIP corrompido', () {
    expect(
      () => extractZipPdfs(
        ZipExtractParams(
          zipPath: _writeCorruptZip(tempDir),
          rootPath: tempDir.path,
          expectedPdfIds: const [],
          skipPdfIds: const [],
        ),
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('ZIP corrompido ou inválido'),
        ),
      ),
    );
  });
}

Future<List<int>> _createZipBytes() async {
  final archive = Archive()
    ..addFile(
      ArchiveFile(
        'ColAdultos/001.pdf',
        5,
        Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]),
      ),
    );
  return ZipEncoder().encode(archive);
}

String _writeCorruptZip(Directory dir) {
  final path = '${dir.path}/corrupt.zip';
  File(path).writeAsBytesSync([0, 1, 2, 3, 4]);
  return path;
}

class _FakeDownloadAdapter implements HttpClientAdapter {
  _FakeDownloadAdapter(
    this._bytes, {
    this.acceptRanges = false,
    this.fullResponseOnRange = false,
  });

  final List<int> _bytes;
  final bool acceptRanges;
  final bool fullResponseOnRange;
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    if (options.method == 'HEAD') {
      return ResponseBody.fromString(
        '',
        200,
        headers: acceptRanges
            ? {
                'accept-ranges': ['bytes']
              }
            : {},
      );
    }

    final rangeHeader = options.headers['Range'] as String?;
    if (rangeHeader != null) {
      if (fullResponseOnRange) {
        return ResponseBody.fromBytes(
          Uint8List.fromList(_bytes),
          200,
          headers: {},
        );
      }

      final start = int.parse(rangeHeader.split('=')[1].split('-')[0]);
      final slice = _bytes.sublist(start);
      return ResponseBody.fromBytes(
        Uint8List.fromList(slice),
        206,
        headers: {
          'content-range': [
            'bytes $start-${_bytes.length - 1}/${_bytes.length}'
          ],
        },
      );
    }

    return ResponseBody.fromBytes(
      Uint8List.fromList(_bytes),
      200,
      headers: {},
    );
  }
}

class _CapturingDownloadAdapter implements HttpClientAdapter {
  _CapturingDownloadAdapter({
    required this.bytes,
    required this.onFetch,
  });

  final List<int> bytes;
  final void Function(RequestOptions options) onFetch;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onFetch(options);
    return ResponseBody.fromBytes(
      Uint8List.fromList(bytes),
      200,
      headers: {},
    );
  }
}

class _RetryOnFirstTimeoutAdapter implements HttpClientAdapter {
  _RetryOnFirstTimeoutAdapter(this._bytes);

  final List<int> _bytes;
  var attempts = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    attempts++;
    if (attempts == 1) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    return ResponseBody.fromBytes(
      Uint8List.fromList(_bytes),
      200,
      headers: {},
    );
  }
}
