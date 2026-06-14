import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:coldigui/core/constants/offline_config.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/datasources/zip_package_downloader.dart';
import 'package:coldigui/features/offline/data/utils/zip_pdf_extractor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'offline_test_helpers.dart';

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
  return ZipEncoder().encode(archive)!;
}

String _writeCorruptZip(Directory dir) {
  final path = '${dir.path}/corrupt.zip';
  File(path).writeAsBytesSync([0, 1, 2, 3, 4]);
  return path;
}

class _FakeDownloadAdapter implements HttpClientAdapter {
  _FakeDownloadAdapter(this._bytes);

  final List<int> _bytes;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      Uint8List.fromList(_bytes),
      200,
      headers: {},
    );
  }
}
