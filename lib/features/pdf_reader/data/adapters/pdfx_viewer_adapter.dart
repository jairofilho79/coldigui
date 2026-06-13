import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../../pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import '../../domain/entities/pdf_reader_preferences.dart';
import '../../domain/ports/pdf_reader_controller_port.dart';
import '../utils/pdf_source_resolver.dart';

/// Adaptador PDFx — isola pacote da camada de domínio (ADR-002).
///
/// A camada de domínio ([OpenPdfDocument], etc.) não importa `pdfx` diretamente.
class PdfxViewerAdapter implements PdfReaderControllerPort {
  PdfxViewerAdapter(
    this._bytesDatasource, {
    PdfSourceResolver? resolver,
  }) : _resolver = resolver ?? const PdfSourceResolver();

  final PdfBytesDatasource _bytesDatasource;
  final PdfSourceResolver _resolver;

  PdfControllerPinch? _controller;

  /// Controller da sessão ativa — ligado via [bindController].
  ///
  /// `null` fora do leitor ou após [unbindController]/[dispose].
  PdfControllerPinch? get controller => _controller;

  /// Liga [controller] da sessão ativa para [SetZoomAndFitMode] / [NavigatePdfPages].
  ///
  /// Chamado pelo [pdfReaderSessionProvider] após [openDocument].
  void bindController(PdfControllerPinch controller) {
    _controller = controller;
  }

  /// Desliga [controller] se for o ativo — chamado no `ref.onDispose` da sessão.
  ///
  /// Idempotente: ignora controllers que não são o bound atual.
  void unbindController(PdfControllerPinch controller) {
    if (identical(_controller, controller)) {
      _controller = null;
    }
  }

  @override
  int? get currentPage {
    final controller = _controller;
    if (controller == null ||
        controller.loadingState.value != PdfLoadingState.success) {
      return null;
    }
    return controller.page;
  }

  @override
  int? get pagesCount => _controller?.pagesCount;

  /// Abre PDF do [filePath] (URL remota, asset ou filesystem local).
  ///
  /// Retorna um [PdfControllerPinch] novo; o lifecycle pertence à sessão
  /// ([pdfReaderSessionProvider]), não ao adapter. Use [bindController] após abrir.
  ///
  /// PDFs remotos são baixados via [Dio] e abertos com [PdfDocument.openData].
  Future<PdfControllerPinch> openDocument(String filePath) async {
    final source = _resolver.resolve(filePath);
    final documentFuture = _openDocument(source);
    return PdfControllerPinch(document: documentFuture);
  }

  Future<PdfDocument> _openDocument(ResolvedPdfSource source) {
    return switch (source.kind) {
      PdfSourceKind.remoteUrl => _openRemote(source.value),
      PdfSourceKind.asset => PdfDocument.openAsset(source.value),
      PdfSourceKind.localFile => PdfDocument.openFile(source.value),
    };
  }

  Future<PdfDocument> _openRemote(String url) async {
    final bytes = await _bytesDatasource.fetchBytes(url);
    return PdfDocument.openData(bytes);
  }

  @override
  Future<void> goToPage(int pageNumber) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.animateToPage(pageNumber: pageNumber);
  }

  @override
  Future<void> nextPage() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Future<void> previousPage() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Future<void> applyFitMode(PdfFitMode mode) async {
    final controller = _controller;
    if (controller == null ||
        controller.loadingState.value != PdfLoadingState.success) {
      return;
    }

    try {
      final pageNumber = controller.page;
      final matrix = switch (mode) {
        PdfFitMode.pageWidth => controller.calculatePageFitMatrix(
            pageNumber: pageNumber,
          ),
        PdfFitMode.pageFit => _calculatePageHeightFitMatrix(
            controller,
            pageNumber: pageNumber,
          ),
      };
      if (matrix != null) {
        await controller.goTo(destination: matrix);
      }
    } on AssertionError {
      // Controller ainda não anexado ao PdfViewPinch.
    } catch (e, st) {
      debugPrint('[PdfxViewerAdapter.applyFitMode] $e\n$st');
    }
  }

  /// Matrix custom para `page-fit` — encaixa pela altura do viewport.
  Matrix4? _calculatePageHeightFitMatrix(
    PdfControllerPinch controller, {
    required int pageNumber,
  }) {
    final pageRect = controller.getPageRect(pageNumber);
    if (pageRect == null || pageRect.height <= 0) return null;

    final viewRect = controller.viewRect;
    final viewHeight = viewRect.height;
    final viewWidth = viewRect.width;
    final scale = viewHeight / pageRect.height;

    final centerX = pageRect.left + pageRect.width / 2;
    final left = centerX - viewWidth / (2 * scale);
    final top = pageRect.top;

    final matrix = Matrix4.identity();
    matrix.storage[0] = scale;
    matrix.storage[5] = scale;
    matrix.storage[12] = -left * scale;
    matrix.storage[13] = -top * scale;
    return matrix;
  }

  /// Safety net no shutdown do app — libera referência residual do controller ativo.
  Future<void> dispose() async {
    _controller?.dispose();
    _controller = null;
  }
}
