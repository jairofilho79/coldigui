import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:coldigui/core/constants/offline_config.dart';

import 'offline_test_helpers.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/datasources/zip_package_downloader.dart';
import 'package:coldigui/features/offline/data/utils/zip_pdf_extractor.dart';
import 'package:coldigui/features/offline/domain/exceptions/offline_bulk_exceptions.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Watchdog injetado nos testes de stall.
///
/// A tentativa **travada** dispara o watchdog só depois desse intervalo, mas a
/// tentativa **que deve concluir** precisa caber dentro dele: armar o timer,
/// `stat` do `.tmp`, uma sondagem HEAD (quando sobra `.tmp` parcial do stall
/// anterior), apagar o `.tmp`, resposta do adapter em memória e gravação de
/// poucos bytes. Com `flutter test` rodando os arquivos em paralelo (vários
/// shards disputando CPU), 500 ms já foi visto sendo insuficiente — a máquina
/// pode pausar o isolate tempo suficiente para essa sequência ultrapassar o
/// watchdog e a retentativa boa ser lida como um segundo stall. 3 s dá folga
/// suficiente para nenhuma classificação depender de jitter do scheduler sob
/// carga, sem exigir mudança no adapter (que já responde instantâneo fora das
/// tentativas listadas em `stallAfterFirstChunkAttempts`). O backoff entre
/// tentativas roda com o guard já descartado (`dispose()` no `finally`), então
/// nunca é confundido com ausência de bytes.
const _testStallTimeout = Duration(seconds: 3);

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
    downloader = ZipPackageDownloader(Dio(), pdfStoragePortFor(store));
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

    final redownloader = ZipPackageDownloader(dio, pdfStoragePortFor(store));
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
    final adapter = _FakeDownloadAdapter(zipBytes, acceptRanges: true);
    dio.httpClientAdapter = adapter;

    final path = await ZipPackageDownloader(dio, pdfStoragePortFor(store))
        .download(
          url: 'http://example.invalid/packages/Partitura-1.zip',
          filename: 'Partitura-1.zip',
          expectedSize: zipBytes.length,
        );

    expect(await File(path).length(), zipBytes.length);
    expect(adapter.requests.any((options) => options.method == 'HEAD'), isTrue);
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

    final path = await ZipPackageDownloader(dio, pdfStoragePortFor(store))
        .download(
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
      ZipPackageDownloader(dio, pdfStoragePortFor(store)).download(
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

    final capturingDownloader = ZipPackageDownloader(
      dio,
      pdfStoragePortFor(store),
    );
    await capturingDownloader.download(
      url: 'http://example.invalid/packages/Partitura-1.zip',
      filename: 'Partitura-1.zip',
    );

    expect(captured, isNotNull);
    expect(captured!.receiveTimeout, OfflineConfig.zipDownloadReceiveTimeout);
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

    final mismatchDownloader = ZipPackageDownloader(
      dio,
      pdfStoragePortFor(store),
    );

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

    final retryDownloader = ZipPackageDownloader(dio, pdfStoragePortFor(store));
    final path = await retryDownloader.download(
      url: 'http://example.invalid/packages/Partitura-1.zip',
      filename: 'Partitura-1.zip',
      expectedSize: zipBytes.length,
    );

    expect(path, target.path);
    expect(await target.length(), zipBytes.length);
    expect((dio.httpClientAdapter as _RetryOnFirstTimeoutAdapter).attempts, 2);
  });

  test('cancelamento do usuário lança ZipDownloadCancelledException', () async {
    final dio = Dio();
    final adapter = _StallingDownloadAdapter(stallAfterFirstChunkAttempts: {1});
    dio.httpClientAdapter = adapter;

    final cancelToken = CancelToken();
    final cancellable = ZipPackageDownloader(dio, pdfStoragePortFor(store));

    final future = cancellable.download(
      url: 'http://example.invalid/packages/Partitura-1.zip',
      filename: 'Partitura-1.zip',
      expectedSize: 4096,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (!cancelToken.isCancelled) {
          cancelToken.cancel('cancelled by user');
        }
      },
    );

    await expectLater(future, throwsA(isA<ZipDownloadCancelledException>()));
    expect(adapter.attempts, 1, reason: 'cancel do usuário não retenta');
  });

  test('stall sem bytes vira ZipDownloadStalledException retryável', () async {
    final zipBytes = await _createZipBytes();
    final dio = Dio();
    final adapter = _StallingDownloadAdapter(
      stallAfterFirstChunkAttempts: {1},
      bytes: zipBytes,
    );
    dio.httpClientAdapter = adapter;

    final stallDownloader = ZipPackageDownloader(
      dio,
      pdfStoragePortFor(store),
      stallTimeout: _testStallTimeout,
    );

    final path = await stallDownloader.download(
      url: 'http://example.invalid/packages/Partitura-1.zip',
      filename: 'Partitura-1.zip',
      expectedSize: zipBytes.length,
    );

    expect(await File(path).length(), zipBytes.length);
    expect(adapter.attempts, 2, reason: 'stall conta como tentativa retryável');
  });

  test(
    'stall em todas as tentativas propaga ZipDownloadStalledException',
    () async {
      final dio = Dio();
      final adapter = _StallingDownloadAdapter(
        stallAfterFirstChunkAttempts: const {1, 2, 3},
      );
      dio.httpClientAdapter = adapter;

      final stallDownloader = ZipPackageDownloader(
        dio,
        pdfStoragePortFor(store),
        stallTimeout: _testStallTimeout,
      );

      await expectLater(
        stallDownloader.download(
          url: 'http://example.invalid/packages/Partitura-1.zip',
          filename: 'Partitura-1.zip',
          expectedSize: 4096,
        ),
        throwsA(isA<ZipDownloadStalledException>()),
      );
      expect(adapter.attempts, OfflineConfig.maxRetryAttempts);
    },
  );

  test(
    'stall no primeiro download mantém o .tmp e a retomada usa Range',
    () async {
      final zipBytes = await _createZipBytes();
      final zipDir = Directory(
        '${docsDir.path}/${OfflineConfig.pdfStorageSubdir}/${OfflineConfig.zipTempSubdir}',
      );
      await zipDir.create(recursive: true);
      final tmp = File('${zipDir.path}/Partitura-1.zip.tmp');

      int? tmpSizeAtProbe;
      final dio = Dio();
      final adapter = _StallThenRangeAdapter(
        zipBytes,
        // A sondagem HEAD só acontece na retomada: se o `.tmp` tivesse sido
        // apagado pelo `deleteOnError` do dio, nem HEAD nem Range existiriam.
        onProbe: () =>
            tmpSizeAtProbe = tmp.existsSync() ? tmp.lengthSync() : null,
      );
      dio.httpClientAdapter = adapter;

      final stallDownloader = ZipPackageDownloader(
        dio,
        pdfStoragePortFor(store),
        stallTimeout: _testStallTimeout,
      );

      final path = await stallDownloader.download(
        url: 'http://example.invalid/packages/Partitura-1.zip',
        filename: 'Partitura-1.zip',
        expectedSize: zipBytes.length,
      );

      expect(
        tmpSizeAtProbe,
        adapter.stalledChunk,
        reason: '.tmp parcial sobreviveu ao stall',
      );
      expect(
        adapter.requests.any(
          (options) =>
              options.headers['Range'] == 'bytes=${adapter.stalledChunk}-',
        ),
        isTrue,
        reason: 'a retomada pediu só o que faltava',
      );
      expect(await File(path).length(), zipBytes.length);
    },
  );

  test('ZIP cacheado sem assinatura PK é apagado e baixado de novo', () async {
    final zipBytes = await _createZipBytes();
    final zipDir = Directory(
      '${docsDir.path}/${OfflineConfig.pdfStorageSubdir}/${OfflineConfig.zipTempSubdir}',
    );
    await zipDir.create(recursive: true);
    final cached = File('${zipDir.path}/Partitura-1.zip');
    // Tamanho correto, conteúdo lixo (ex.: HTML de erro do proxy).
    await cached.writeAsBytes(List<int>.filled(zipBytes.length, 0x41));

    final dio = Dio();
    final adapter = _FakeDownloadAdapter(zipBytes);
    dio.httpClientAdapter = adapter;

    final path = await ZipPackageDownloader(dio, pdfStoragePortFor(store))
        .download(
          url: 'http://example.invalid/packages/Partitura-1.zip',
          filename: 'Partitura-1.zip',
          expectedSize: zipBytes.length,
        );

    expect(await File(path).readAsBytes(), zipBytes);
    expect(
      adapter.requests,
      isNotEmpty,
      reason: 'cache inválido foi rebaixado',
    );
  });

  test('ZIP cacheado sem expectedSize também exige assinatura PK', () async {
    final zipBytes = await _createZipBytes();
    final zipDir = Directory(
      '${docsDir.path}/${OfflineConfig.pdfStorageSubdir}/${OfflineConfig.zipTempSubdir}',
    );
    await zipDir.create(recursive: true);
    final cached = File('${zipDir.path}/Partitura-1.zip');
    await cached.writeAsString('<html>404</html>');

    final dio = Dio();
    dio.httpClientAdapter = _FakeDownloadAdapter(zipBytes);

    final path = await ZipPackageDownloader(dio, pdfStoragePortFor(store))
        .download(
          url: 'http://example.invalid/packages/Partitura-1.zip',
          filename: 'Partitura-1.zip',
        );

    expect(await File(path).readAsBytes(), zipBytes);
  });

  test('cleanOrphanedTempFiles preserva os .tmp listados em keep', () async {
    final zipDir = Directory(
      '${docsDir.path}/${OfflineConfig.pdfStorageSubdir}/${OfflineConfig.zipTempSubdir}',
    );
    await zipDir.create(recursive: true);

    final keptTmp = File('${zipDir.path}/Partitura-2.zip.tmp');
    final orphanTmp = File('${zipDir.path}/Cifra-9.zip.tmp');
    await keptTmp.writeAsString('checkpoint ativo');
    await orphanTmp.writeAsString('órfão');

    await downloader.cleanOrphanedTempFiles(keep: {'Partitura-2.zip'});

    expect(await keptTmp.exists(), isTrue);
    expect(await orphanTmp.exists(), isFalse);
  });

  test('download limpa órfãos mas preserva o .tmp do checkpoint ativo', () async {
    final zipBytes = await _createZipBytes();
    final zipDir = Directory(
      '${docsDir.path}/${OfflineConfig.pdfStorageSubdir}/${OfflineConfig.zipTempSubdir}',
    );
    await zipDir.create(recursive: true);

    final checkpointTmp = File('${zipDir.path}/Partitura-2.zip.tmp');
    final orphanTmp = File('${zipDir.path}/Cifra-9.zip.tmp');
    await checkpointTmp.writeAsString('checkpoint ativo');
    await orphanTmp.writeAsString('órfão');

    final dio = Dio();
    dio.httpClientAdapter = _FakeDownloadAdapter(zipBytes);

    await ZipPackageDownloader(dio, pdfStoragePortFor(store)).download(
      url: 'http://example.invalid/packages/Partitura-1.zip',
      filename: 'Partitura-1.zip',
      expectedSize: zipBytes.length,
      activeCheckpointName: 'Partitura-2.zip',
    );

    expect(await checkpointTmp.exists(), isTrue);
    expect(await orphanTmp.exists(), isFalse);
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
                'accept-ranges': ['bytes'],
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
            'bytes $start-${_bytes.length - 1}/${_bytes.length}',
          ],
        },
      );
    }

    return ResponseBody.fromBytes(Uint8List.fromList(_bytes), 200, headers: {});
  }
}

/// Emite um chunk e trava (sem mais bytes, sem fechar) nas tentativas listadas.
///
/// [attempts] conta só requests de download: um `HEAD` de sondagem de Range
/// (que aparece se o `.tmp` parcial ainda não tiver sido apagado pelo dio) não
/// desloca a numeração das tentativas nem a asserção dos testes.
class _StallingDownloadAdapter implements HttpClientAdapter {
  _StallingDownloadAdapter({
    required this.stallAfterFirstChunkAttempts,
    List<int>? bytes,
  }) : _bytes = bytes ?? List<int>.filled(4096, 0x50);

  final Set<int> stallAfterFirstChunkAttempts;
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
    final headers = {
      'content-length': ['${_bytes.length}'],
    };

    // Sem `accept-ranges`: o downloader cai no download completo.
    if (options.method == 'HEAD') {
      return ResponseBody.fromString('', 200, headers: {});
    }

    attempts++;

    if (!stallAfterFirstChunkAttempts.contains(attempts)) {
      return ResponseBody.fromBytes(
        Uint8List.fromList(_bytes),
        200,
        headers: headers,
      );
    }

    final controller = StreamController<Uint8List>();
    controller.onCancel = () {};
    controller.add(Uint8List.fromList(_bytes.sublist(0, 1)));
    return ResponseBody(controller.stream, 200, headers: headers);
  }
}

/// Trava a 1ª tentativa depois de meio arquivo e serve o resto por Range.
///
/// O `HEAD` responde `accept-ranges: bytes` para o downloader escolher a
/// retomada; [onProbe] é o gancho que mede o `.tmp` exatamente entre o stall e
/// a requisição com `Range`.
class _StallThenRangeAdapter implements HttpClientAdapter {
  _StallThenRangeAdapter(this._bytes, {required this.onProbe});

  final List<int> _bytes;
  final void Function() onProbe;
  final List<RequestOptions> requests = [];
  var attempts = 0;

  /// Bytes entregues antes de a 1ª tentativa travar.
  int get stalledChunk => _bytes.length ~/ 2;

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
      onProbe();
      return ResponseBody.fromString(
        '',
        200,
        headers: {
          'accept-ranges': ['bytes'],
        },
      );
    }

    attempts++;

    final rangeHeader = options.headers['Range'] as String?;
    if (rangeHeader != null) {
      final start = int.parse(rangeHeader.split('=')[1].split('-')[0]);
      return ResponseBody.fromBytes(
        Uint8List.fromList(_bytes.sublist(start)),
        206,
        headers: {
          'content-range': [
            'bytes $start-${_bytes.length - 1}/${_bytes.length}',
          ],
        },
      );
    }

    final headers = {
      'content-length': ['${_bytes.length}'],
    };

    if (attempts == 1) {
      final controller = StreamController<Uint8List>();
      controller.onCancel = () {};
      controller.add(Uint8List.fromList(_bytes.sublist(0, stalledChunk)));
      return ResponseBody(controller.stream, 200, headers: headers);
    }

    return ResponseBody.fromBytes(
      Uint8List.fromList(_bytes),
      200,
      headers: headers,
    );
  }
}

class _CapturingDownloadAdapter implements HttpClientAdapter {
  _CapturingDownloadAdapter({required this.bytes, required this.onFetch});

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
    return ResponseBody.fromBytes(Uint8List.fromList(bytes), 200, headers: {});
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
    return ResponseBody.fromBytes(Uint8List.fromList(_bytes), 200, headers: {});
  }
}
