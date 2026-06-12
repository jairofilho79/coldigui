import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// Limiar de distância horizontal mínima para considerar um swipe de troca de página.
const kPdfPageSwipeMinDistance = 48.0;

/// Fator mínimo horizontal/vertical para distinguir swipe de scroll vertical.
const kPdfPageSwipeHorizontalDominanceFactor = 1.2;

/// Tolerância em pixels para considerar o viewport encostado na borda da página.
const kPdfPageSwipeEdgeTolerance = 12.0;

/// Política de quando um swipe horizontal pode trocar de página sem conflitar
/// com pan horizontal ou pinch-to-zoom do [PdfViewPinch].
///
/// Consumida por [PdfxPdfView] no `onPointerUp`. Constantes públicas:
/// [kPdfPageSwipeMinDistance], [kPdfPageSwipeHorizontalDominanceFactor],
/// [kPdfPageSwipeEdgeTolerance].
abstract final class PdfPageSwipePolicy {
  /// Retorna `true` se um swipe direita→esquerda pode avançar para a próxima página.
  ///
  /// Exige documento carregado. Com pan horizontal disponível (zoom), só permite
  /// na borda direita da página atual.
  static bool canGoToNextPage(PdfControllerPinch controller) {
    return _canTurnPage(controller, trailingEdge: true);
  }

  /// Retorna `true` se um swipe esquerda→direita pode voltar à página anterior.
  ///
  /// Exige documento carregado. Com pan horizontal disponível (zoom), só permite
  /// na borda esquerda da página atual.
  static bool canGoToPreviousPage(PdfControllerPinch controller) {
    return _canTurnPage(controller, trailingEdge: false);
  }

  static bool _canTurnPage(
    PdfControllerPinch controller, {
    required bool trailingEdge,
  }) {
    if (controller.loadingState.value != PdfLoadingState.success) {
      return false;
    }

    final pageRect = controller.getPageRect(controller.page);
    if (pageRect == null) return false;

    final viewWidth = controller.viewRect.width;
    if (!hasHorizontalPanRoom(
      pageRect: pageRect,
      zoomRatio: controller.zoomRatio,
      viewWidth: viewWidth,
    )) {
      return true;
    }

    return isAtHorizontalEdge(
      transform: controller.value,
      pageRect: pageRect,
      viewWidth: viewWidth,
      trailingEdge: trailingEdge,
    );
  }

  /// Indica se a página atual é mais larga que o viewport (pan horizontal possível).
  @visibleForTesting
  static bool hasHorizontalPanRoom({
    required Rect pageRect,
    required double zoomRatio,
    required double viewWidth,
  }) {
    return pageRect.width * zoomRatio > viewWidth + kPdfPageSwipeEdgeTolerance;
  }

  /// Verifica se o viewport está encostado na borda esquerda ou direita da página.
  @visibleForTesting
  static bool isAtHorizontalEdge({
    required Matrix4 transform,
    required Rect pageRect,
    required double viewWidth,
    required bool trailingEdge,
  }) {
    final zoomRatio = transform.row0[0];
    final viewLeft = -transform.row0[3];
    final viewRight = viewLeft + viewWidth;

    final pageLeft = pageRect.left * zoomRatio;
    final pageRight = pageRect.right * zoomRatio;

    if (trailingEdge) {
      return viewRight >= pageRight - kPdfPageSwipeEdgeTolerance;
    }
    return viewLeft <= pageLeft + kPdfPageSwipeEdgeTolerance;
  }

  /// Retorna `true` se [totalDelta] configura um swipe horizontal válido.
  ///
  /// Exige \|dx\| ≥ [kPdfPageSwipeMinDistance] e dominância horizontal
  /// ([kPdfPageSwipeHorizontalDominanceFactor] × \|dy\|).
  static bool isHorizontalSwipe(Offset totalDelta) {
    final dx = totalDelta.dx;
    final dy = totalDelta.dy;
    if (dx.abs() < kPdfPageSwipeMinDistance) return false;
    return dx.abs() > dy.abs() * kPdfPageSwipeHorizontalDominanceFactor;
  }
}
