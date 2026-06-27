import 'package:flutter/material.dart';

import 'pdf_page_swipe_policy.dart';

/// Fração da largura do canvas reservada para toque de troca de página (1/5).
const kPdfPageEdgeTapZoneFraction = 0.2;

/// Distância máxima (px) para considerar um toque estrito nas bordas.
const kPdfPageEdgeTapMaxMovement = 8.0;

/// Política de navegação por toque nas bordas do canvas (UC-11).
///
/// Divide a largura em 5 faixas iguais: 20% esquerda volta, 20% direita avança.
/// Diferente do swipe, **não** aplica [PdfPageSwipePolicy.canGoToNextPage] /
/// [canGoToPreviousPage] — toque na borda sempre troca de página, mesmo com zoom/pan.
abstract final class PdfPageEdgeTapPolicy {
  /// Retorna a direção de troca para [localX] no canvas, ou `null` se no centro.
  static PdfPageSwipeDirection? directionForDownPosition({
    required double localX,
    required double canvasWidth,
  }) {
    if (canvasWidth <= 0) return null;

    final edgeWidth = canvasWidth * kPdfPageEdgeTapZoneFraction;
    if (localX < edgeWidth) return PdfPageSwipeDirection.previous;
    if (localX > canvasWidth - edgeWidth) return PdfPageSwipeDirection.next;
    return null;
  }

  /// Retorna `true` se [totalDelta] configura um toque estrito (sem pan/scroll).
  static bool isStrictTap(Offset totalDelta) {
    return totalDelta.distance < kPdfPageEdgeTapMaxMovement;
  }
}
