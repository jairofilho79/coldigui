import 'package:flutter/material.dart';

import '../../data/models/pdf_reader_viewer_handle.dart';

/// Limiar de distância horizontal mínima para considerar um swipe de troca de página.
const kPdfPageSwipeMinDistance = 48.0;

/// Fator mínimo horizontal/vertical para distinguir swipe de scroll vertical.
const kPdfPageSwipeHorizontalDominanceFactor = 1.2;

/// Tolerância em pixels para considerar o viewport encostado na borda da página.
const kPdfPageSwipeEdgeTolerance = 12.0;

/// Direção de troca de página reconhecida durante um swipe horizontal.
enum PdfPageSwipeDirection {
  /// Swipe direita→esquerda — avança para a próxima página.
  next,

  /// Swipe esquerda→direita — volta para a página anterior.
  previous,
}

/// Política de quando um swipe horizontal pode trocar de página sem conflitar
/// com pan horizontal ou pinch-to-zoom do viewer.
abstract final class PdfPageSwipePolicy {
  /// Distância horizontal mínima para feedback e reconhecimento de swipe.
  static double get minHorizontalDx => kPdfPageSwipeMinDistance;

  /// Retorna `true` se um swipe direita→esquerda pode avançar para a próxima página.
  static bool canGoToNextPage(PdfViewportSnapshot snapshot) {
    return _canTurnPage(snapshot, trailingEdge: true);
  }

  /// Retorna `true` se um swipe esquerda→direita pode voltar à página anterior.
  static bool canGoToPreviousPage(PdfViewportSnapshot snapshot) {
    return _canTurnPage(snapshot, trailingEdge: false);
  }

  static bool _canTurnPage(
    PdfViewportSnapshot snapshot, {
    required bool trailingEdge,
  }) {
    final pageRect = snapshot.pageRect;

    final viewWidth = snapshot.viewWidth;
    if (!hasHorizontalPanRoom(
      pageRect: pageRect,
      zoomRatio: snapshot.zoomRatio,
      viewWidth: viewWidth,
    )) {
      return true;
    }

    return isAtHorizontalEdge(
      transform: snapshot.transform,
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
  static bool isHorizontalSwipe(Offset totalDelta) {
    final dx = totalDelta.dx;
    final dy = totalDelta.dy;
    if (dx.abs() < kPdfPageSwipeMinDistance) return false;
    return dx.abs() > dy.abs() * kPdfPageSwipeHorizontalDominanceFactor;
  }

  /// Retorna a direção do swipe horizontal ativo, ou `null` se o gesto ainda
  /// não atingiu o threshold ou não é predominantemente horizontal.
  static PdfPageSwipeDirection? activeHorizontalSwipe(Offset totalDelta) {
    if (!isHorizontalSwipe(totalDelta)) return null;
    return totalDelta.dx < 0
        ? PdfPageSwipeDirection.next
        : PdfPageSwipeDirection.previous;
  }
}
