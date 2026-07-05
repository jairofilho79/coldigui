import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import '../../domain/entities/pdf_reader_preferences.dart';
import '../../domain/ports/pdf_reader_controller_port.dart';
import '../pdfrx_bootstrap.dart';
import '../models/pdf_reader_viewer_handle.dart';
import '../utils/pdf_source_resolver.dart';

/// Adaptador pdfrx — isola pacote da camada de domínio (ADR-002 / Fase C).
class PdfrxViewerAdapter implements PdfReaderControllerPort {
  PdfrxViewerAdapter(this._bytesDatasource, {PdfSourceResolver? resolver})
    : _resolver = resolver ?? const PdfSourceResolver();

  final PdfBytesDatasource _bytesDatasource;
  final PdfSourceResolver _resolver;

  PdfReaderViewerHandle? _activeHandle;

  /// Handle da sessão ativa — ligado via [bindHandle].
  PdfReaderViewerHandle? get activeHandle => _activeHandle;

  /// Liga [handle] da sessão ativa para [SetZoomAndFitMode] / [NavigatePdfPages].
  void bindHandle(PdfReaderViewerHandle handle) {
    _activeHandle = handle;
  }

  /// Desliga [handle] se for o ativo — chamado no `ref.onDispose` da sessão.
  void unbindHandle(PdfReaderViewerHandle handle) {
    if (identical(_activeHandle, handle)) {
      _activeHandle = null;
    }
  }

  @override
  int? get currentPage {
    final handle = _activeHandle;
    if (handle == null || !handle.isViewerReady) return null;
    return handle.page;
  }

  @override
  int? get pagesCount => _activeHandle?.pagesCount;

  /// Abre PDF do [filePath] (URL remota, asset ou filesystem local).
  ///
  /// Retorna um [PdfReaderViewerHandle] novo; o lifecycle pertence à sessão
  /// ([pdfReaderSessionProvider]), não ao adapter.
  Future<PdfReaderViewerHandle> openDocument(String filePath) async {
    await ensurePdfrxInitialized();
    final source = _resolver.resolve(filePath);
    final document = await _openDocument(source);
    final documentRef = PdfDocumentRefDirect(document, autoDispose: false);
    final controller = PdfViewerController();
    return PdfReaderViewerHandle(
      document: document,
      documentRef: documentRef,
      viewerController: controller,
    );
  }

  Future<PdfDocument> _openDocument(ResolvedPdfSource source) {
    Timeline.startSync(
      'PdfDocument.open',
      arguments: <String, String>{'kind': source.kind.name},
    );
    final documentFuture = switch (source.kind) {
      PdfSourceKind.remoteUrl => _openRemote(source.value),
      PdfSourceKind.asset => PdfDocument.openAsset(source.value),
      PdfSourceKind.localFile => _openLocal(source.value),
    };
    return documentFuture.whenComplete(Timeline.finishSync);
  }

  Future<PdfDocument> _openRemote(String url) async {
    final bytes = await _bytesDatasource.fetchBytes(url);
    return PdfDocument.openData(bytes, sourceName: url);
  }

  /// D2 OA — local sempre via bytes; web não usa [PdfDocument.openFile].
  Future<PdfDocument> _openLocal(String path) async {
    final bytes = await _bytesDatasource.fetchBytes(path);
    return PdfDocument.openData(bytes, sourceName: path);
  }

  @override
  Future<void> goToPage(int pageNumber) async {
    final handle = _activeHandle;
    if (handle == null || !handle.isViewerReady) return;
    await handle.viewerController.goToPage(
      pageNumber: pageNumber,
      duration: const Duration(milliseconds: 300),
    );
    handle.onPageChanged(pageNumber);
  }

  @override
  Future<void> nextPage() async {
    final handle = _activeHandle;
    if (handle == null || !handle.isViewerReady) return;
    final current = handle.page;
    final total = handle.pagesCount;
    if (total == null || current >= total) return;
    await goToPage(current + 1);
  }

  @override
  Future<void> previousPage() async {
    final handle = _activeHandle;
    if (handle == null || !handle.isViewerReady) return;
    final current = handle.page;
    if (current <= 1) return;
    await goToPage(current - 1);
  }

  @override
  Future<void> applyFitMode(PdfFitMode mode) async {
    final handle = _activeHandle;
    if (handle == null || !handle.isViewerReady) return;

    final controller = handle.viewerController;
    if (!controller.isReady) return;

    try {
      final pageNumber = controller.pageNumber ?? handle.page;
      final matrix = switch (mode) {
        PdfFitMode.pageWidth => controller.calcMatrixFitWidthForPage(
          pageNumber: pageNumber,
        ),
        PdfFitMode.pageFit => controller.calcMatrixFitHeightForPage(
          pageNumber: pageNumber,
        ),
      };
      if (matrix != null) {
        await controller.goTo(matrix);
      }
    } on AssertionError {
      // Controller ainda não anexado ao PdfViewer.
    } catch (e, st) {
      debugPrint('[PdfrxViewerAdapter.applyFitMode] $e\n$st');
    }
  }

  /// Safety net no shutdown do app — libera referência residual do handle ativo.
  Future<void> dispose() async {
    _activeHandle?.dispose();
    _activeHandle = null;
  }
}
