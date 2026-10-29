import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';

/// Aspecto mínimo do viewport (`largura / altura`) para habilitar o layout
/// em spread — duas páginas lado a lado (spec A.4 C8).
const kSpreadMinViewportAspect = 1.3;

/// Layout de páginas do leitor PDF em pares lado a lado — 1–2, 3–4, … — como
/// folhas soltas (sem página solitária à esquerda quando o total é ímpar;
/// a última página, sozinha, ocupa uma linha inteira) — spec A.4 C8.
///
/// Ativo só quando [viewportAspect] > [kSpreadMinViewportAspect] **e**
/// [pages] tem mais de uma página; caso contrário delega a [fallback] — o
/// layout padrão do pdfrx (ver [defaultPdfPageLayout]).
///
/// Ligado em [PdfViewerParams.layoutPages].
PdfPageLayout spreadPageLayout(
  List<PdfPage> pages,
  PdfViewerParams params, {
  required double viewportAspect,
  required PdfPageLayout Function(List<PdfPage> pages, PdfViewerParams params)
  fallback,
}) {
  if (viewportAspect <= kSpreadMinViewportAspect || pages.length <= 1) {
    return fallback(pages, params);
  }

  final margin = params.margin;
  final pageLayouts = <Rect>[];
  var y = margin;
  var documentWidth = 0.0;

  for (var i = 0; i < pages.length; i += 2) {
    final left = pages[i];
    final right = i + 1 < pages.length ? pages[i + 1] : null;

    var x = margin;
    pageLayouts.add(Rect.fromLTWH(x, y, left.width, left.height));
    x += left.width + margin;

    var rowHeight = left.height;
    if (right != null) {
      pageLayouts.add(Rect.fromLTWH(x, y, right.width, right.height));
      x += right.width + margin;
      rowHeight = math.max(rowHeight, right.height);
    }

    documentWidth = math.max(documentWidth, x);
    y += rowHeight + margin;
  }

  return PdfPageLayout(
    pageLayouts: pageLayouts,
    documentSize: Size(documentWidth, y),
  );
}

/// Layout padrão do pdfrx — coluna única, páginas centralizadas
/// horizontalmente e empilhadas verticalmente (scroll vertical contínuo).
///
/// Replica `_PdfViewerState._layoutPages` (privado em `package:pdfrx`)
/// porque definir [PdfViewerParams.layoutPages] substitui o layout padrão
/// por inteiro — usado como [spreadPageLayout]'s `fallback` em produção
/// (viewport estreito ou documento de 1 página só).
PdfPageLayout defaultPdfPageLayout(
  List<PdfPage> pages,
  PdfViewerParams params,
) {
  final margin = params.margin;
  final width =
      pages.fold(0.0, (w, page) => math.max(w, page.width)) + margin * 2;

  final pageLayouts = <Rect>[];
  var y = margin;
  for (final page in pages) {
    pageLayouts.add(
      Rect.fromLTWH((width - page.width) / 2, y, page.width, page.height),
    );
    y += page.height + margin;
  }

  return PdfPageLayout(pageLayouts: pageLayouts, documentSize: Size(width, y));
}
