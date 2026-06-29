import 'dart:async';

import 'package:coldigui/features/pdf_reader/data/models/pdf_reader_viewer_handle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

/// Documento fake para testes de cache/sessão — sem I/O de PDF real.
class FakePdfDocument extends Fake implements PdfDocument {
  FakePdfDocument({this.pageCount = 1});

  final int pageCount;
  var disposeCallCount = 0;

  @override
  String get sourceName => 'fake://test';

  @override
  List<PdfPage> get pages =>
      List<PdfPage>.generate(pageCount, (i) => FakePdfPage(i + 1));

  @override
  bool get isEncrypted => false;

  @override
  PdfPermissions? get permissions => null;

  @override
  Stream<PdfDocumentEvent> get events => const Stream.empty();

  @override
  Future<void> dispose() async {
    disposeCallCount++;
  }
}

class FakePdfPage extends Fake implements PdfPage {
  FakePdfPage(this.pageNumber);

  @override
  final int pageNumber;
}

/// Handle rastreável para asserts de lifecycle em testes.
class TrackablePdfReaderViewerHandle extends PdfReaderViewerHandle {
  TrackablePdfReaderViewerHandle({
    required super.document,
    required super.documentRef,
    required super.viewerController,
  });

  var wasDisposed = false;

  @override
  void dispose() {
    if (wasDisposed) return;
    wasDisposed = true;
    super.dispose();
  }
}

TrackablePdfReaderViewerHandle createTrackableHandle({int pageCount = 1}) {
  final document = FakePdfDocument(pageCount: pageCount);
  return TrackablePdfReaderViewerHandle(
    document: document,
    documentRef: PdfDocumentRefDirect(document, autoDispose: false),
    viewerController: PdfViewerController(),
  );
}
