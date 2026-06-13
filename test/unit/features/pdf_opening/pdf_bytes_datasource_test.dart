import 'dart:io';

import 'package:coldigui/core/constants/offline_config.dart';
import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:coldigui/features/pdf_reader/data/utils/pdf_source_resolver.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDio implements Dio {
  _FakeDio(this._bytes);

  final Uint8List _bytes;
  Options? lastOptions;
  int progressInvocations = 0;
  ProgressCallback? lastOnReceiveProgress;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    lastOptions = options;
    lastOnReceiveProgress = onReceiveProgress;
    onReceiveProgress?.call(_bytes.length, _bytes.length);
    progressInvocations = onReceiveProgress != null ? 1 : 0;
    return Response<T>(
      data: _bytes as T,
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBundle extends AssetBundle {
  _FakeBundle(this._bytes);

  final Uint8List _bytes;

  @override
  Future<ByteData> load(String key) async {
    return _bytes.buffer.asByteData();
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    throw UnimplementedError();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfBytesDatasource', () {
    test('fetchBytes remoto retorna bytes do Dio', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final datasource = PdfBytesDatasource(
        _FakeDio(bytes),
        resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
      );

      final result = await datasource.fetchBytes(
        'https://example.com/assets/test.pdf',
      );

      expect(result, bytes);
    });

    test('fetchBytes remoto usa timeouts específicos de OfflineConfig',
        () async {
      final dio = _FakeDio(Uint8List.fromList([1]));
      final datasource = PdfBytesDatasource(
        dio,
        resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
      );

      await datasource.fetchBytes('https://example.com/assets/test.pdf');

      expect(dio.lastOptions?.responseType, ResponseType.bytes);
      expect(
        dio.lastOptions?.receiveTimeout,
        OfflineConfig.pdfDownloadReceiveTimeout,
      );
      expect(
        dio.lastOptions?.sendTimeout,
        OfflineConfig.pdfDownloadSendTimeout,
      );
    });

    test('fetchBytes remoto repassa onReceiveProgress ao Dio', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final dio = _FakeDio(bytes);
      final datasource = PdfBytesDatasource(
        dio,
        resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
      );
      var progressCalls = 0;

      await datasource.fetchBytes(
        'https://example.com/assets/test.pdf',
        onReceiveProgress: (_, __) => progressCalls++,
      );

      expect(progressCalls, dio.progressInvocations);
      expect(dio.progressInvocations, greaterThan(0));
    });

    test('fetchBytes remoto lança quando resposta vazia', () async {
      final datasource = PdfBytesDatasource(
        _FakeDio(Uint8List(0)),
        resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
      );

      await expectLater(
        datasource.fetchBytes('https://example.com/assets/empty.pdf'),
        throwsA(isA<Exception>()),
      );
    });

    test('fetchBytes asset via rootBundle', () async {
      final bytes = Uint8List.fromList([10, 20, 30]);
      final datasource = PdfBytesDatasource(
        _FakeDio(Uint8List(0)),
        resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
        bundle: _FakeBundle(bytes),
      );

      final result = await datasource.fetchBytes('asset:fixtures/sample.pdf');

      expect(result, bytes);
    });

    test('fetchBytes local lê arquivo do disco', () async {
      final tempDir = await Directory.systemTemp.createTemp('pdf_bytes_test');
      final file = File('${tempDir.path}/local.pdf');
      await file.writeAsBytes([5, 6, 7]);

      final datasource = PdfBytesDatasource(
        _FakeDio(Uint8List(0)),
        resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
      );

      final result = await datasource.fetchBytes(file.path);

      expect(result, Uint8List.fromList([5, 6, 7]));

      await tempDir.delete(recursive: true);
    });
  });
}
