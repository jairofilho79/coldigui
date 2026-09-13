import 'dart:io';

import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:coldigui/features/pdf_reader/data/adapters/pdfrx_viewer_adapter.dart';
import 'package:coldigui/features/pdf_reader/data/models/pdf_reader_viewer_handle.dart';
import 'package:coldigui/features/pdf_reader/data/utils/pdf_source_resolver.dart';
import 'package:coldigui/features/pdf_reader/domain/entities/pdf_reader_preferences.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/pdf_local_open_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'pdf_reader_test_helpers.dart';

class _FakeDio implements Dio {
  _FakeDio(this._bytes);

  final Uint8List _bytes;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    return Response<T>(
      data: _bytes as T,
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PdfBytesDatasource _datasource(Uint8List bytes) {
  return PdfBytesDatasource(
    _FakeDio(bytes),
    resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
  );
}

PdfrxViewerAdapter _adapter() {
  return PdfrxViewerAdapter(
    _datasource(Uint8List(0)),
    resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PdfrxViewerAdapter dispose limpa handle inativo', () async {
    final adapter = PdfrxViewerAdapter(
      _datasource(Uint8List(0)),
      resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
    );

    await adapter.dispose();
    expect(adapter.activeHandle, isNull);
  });

  test('getters seguros retornam null sem handle', () {
    final adapter = PdfrxViewerAdapter(
      _datasource(Uint8List(0)),
      resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
    );

    expect(adapter.currentPage, isNull);
    expect(adapter.pagesCount, isNull);
  });

  test('navegação não lança sem handle ativo', () async {
    final adapter = PdfrxViewerAdapter(
      _datasource(Uint8List(0)),
      resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
    );

    await expectLater(adapter.goToPage(1), completes);
    await expectLater(adapter.nextPage(), completes);
    await expectLater(adapter.previousPage(), completes);
    await expectLater(adapter.applyFitMode(PdfFitMode.pageFit), completes);
  });

  test('bindHandle e unbindHandle ligam sessão ativa', () {
    final adapter = _adapter();
    final handle = createTrackableHandle();
    addTearDown(handle.dispose);

    adapter.bindHandle(handle);
    expect(adapter.activeHandle, same(handle));

    adapter.unbindHandle(handle);
    expect(adapter.activeHandle, isNull);
  });

  test('unbindHandle ignora handle que não é o ativo', () {
    final adapter = _adapter();
    final active = createTrackableHandle();
    final other = createTrackableHandle();
    addTearDown(active.dispose);
    addTearDown(other.dispose);

    adapter.bindHandle(active);
    adapter.unbindHandle(other);

    expect(adapter.activeHandle, same(active));
  });

  test('openDocument não dispose handle anterior', () async {
    final adapter = _OpenDocumentTestAdapter();
    final previous = createTrackableHandle();
    addTearDown(previous.dispose);

    adapter.bindHandle(previous);
    final created = await adapter.openDocument('asset:fixtures/sample.pdf');

    expect(created, isNot(same(previous)));
    expect(adapter.activeHandle, same(previous));
    addTearDown(created.dispose);
  });

  test('applyFitMode ignora handle sem viewer pronto', () async {
    final adapter = _adapter();
    final handle = createTrackableHandle();
    addTearDown(handle.dispose);

    adapter.bindHandle(handle);
    await expectLater(adapter.applyFitMode(PdfFitMode.pageFit), completes);
  });

  test('applyFitMode registra erros inesperados sem propagar', () async {
    final adapter = _FitModeThrowingAdapter();
    final handle = _FitModeThrowingHandle();
    addTearDown(handle.dispose);

    adapter.bindHandle(handle);
    handle.markViewerReady();

    final logs = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      logs.add(message ?? '');
    };
    addTearDown(() => debugPrint = originalDebugPrint);

    await expectLater(adapter.applyFitMode(PdfFitMode.pageWidth), completes);

    expect(
      logs.any((line) => line.contains('[PdfrxViewerAdapter.applyFitMode]')),
      isTrue,
    );
  });

  // UC-11 B3: o veredito do magic `%PDF` vem dos bytes que o adapter leu
  // (datasource com import condicional), nunca de `dart:io` na presentation.
  //
  // DÍVIDA TÉCNICA (skip, 2026-09-13 — polimento): estes 3 testes abrem um
  // PDF de verdade e por isso precisam do pdfium nativo dentro do VM do
  // `flutter test`. `pdfium_dart` 0.2.5 só o encontra via
  // `.dart_tool/native_assets.yaml` (ausente no macOS com `FLUTTER_TEST`) e o
  // `BackgroundWorker` do pdfrx fica pendurado até o timeout de 30 s —
  // «Failed to load PDFium module … Native assets file not found». Reproduz
  // no checkout principal e em worktrees novos, independente do código do
  // app. Sanar num polimento futuro: apontar `Pdfrx.pdfiumModulePath` para
  // `build/native_assets/macos/libpdfium.dylib` num helper de teste (como já
  // se faz com o Isar em `test/helpers/isar_plus_test_init.dart`) ou exigir
  // `--platform chrome`, e então remover este `skip`.
  group(
    'openDocument local — evidência de magic bytes (B3)',
    () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('pdfrx_adapter_b3_');
        // pdfrx pede diretório temporário ao path_provider na inicialização.
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (call) async => tempDir.path,
            );
      });

      tearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              null,
            );
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      });

      Future<String> writeLocalPdf(String name, List<int> bytes) async {
        final file = File('${tempDir.path}/$name');
        await file.writeAsBytes(bytes);
        return file.path;
      }

      test(
        'bytes lidos sem %PDF -> PdfLocalOpenFailure(hasValidMagicBytes: false)',
        () async {
          final path = await writeLocalPdf(
            'nao_e_pdf.pdf',
            '<html>erro do servidor</html>'.codeUnits,
          );

          await expectLater(
            _adapter().openDocument(path),
            throwsA(
              isA<PdfLocalOpenFailure>().having(
                (e) => e.hasValidMagicBytes,
                'hasValidMagicBytes',
                isFalse,
              ),
            ),
          );
        },
      );

      test('bytes lidos com %PDF mas documento inválido -> '
          'PdfLocalOpenFailure(hasValidMagicBytes: true)', () async {
        final path = await writeLocalPdf('quebrado.pdf', [
          ...'%PDF-1.7\n'.codeUnits,
          ...List<int>.filled(64, 0x00),
        ]);

        await expectLater(
          _adapter().openDocument(path),
          throwsA(
            isA<PdfLocalOpenFailure>().having(
              (e) => e.hasValidMagicBytes,
              'hasValidMagicBytes',
              isTrue,
            ),
          ),
        );
      });

      test('falha na LEITURA dos bytes não vira PdfLocalOpenFailure', () async {
        final path = '${tempDir.path}/inexistente.pdf';

        await expectLater(
          _adapter().openDocument(path),
          throwsA(isNot(isA<PdfLocalOpenFailure>())),
        );
      });
    },
    skip:
        'Dívida técnica: pdfium nativo não carrega no VM de teste '
        '(pdfium_dart 0.2.5 exige .dart_tool/native_assets.yaml) — ver '
        'comentário do group.',
  );
}

class _FitModeThrowingHandle extends PdfReaderViewerHandle {
  _FitModeThrowingHandle()
    : super(
        document: _sharedDoc,
        documentRef: PdfDocumentRefDirect(_sharedDoc, autoDispose: false),
        viewerController: _ThrowingViewerController(),
      );

  static final _sharedDoc = FakePdfDocument();

  @override
  bool get isViewerReady => true;
}

class _OpenDocumentTestAdapter extends PdfrxViewerAdapter {
  _OpenDocumentTestAdapter()
    : super(
        PdfBytesDatasource(
          _FakeDio(Uint8List(0)),
          resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
        ),
      );

  @override
  Future<PdfReaderViewerHandle> openDocument(String filePath) async {
    return createTrackableHandle();
  }
}

class _ThrowingViewerController extends PdfViewerController {
  @override
  bool get isReady => true;

  @override
  int? get pageNumber => 1;

  @override
  Matrix4? calcMatrixFitWidthForPage({required int pageNumber}) {
    throw StateError('unexpected fit failure');
  }
}

class _FitModeThrowingAdapter extends PdfrxViewerAdapter {
  _FitModeThrowingAdapter()
    : super(
        PdfBytesDatasource(
          _FakeDio(Uint8List(0)),
          resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
        ),
      );
}
