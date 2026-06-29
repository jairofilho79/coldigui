import 'package:flutter/material.dart';

/// Âncora do share sheet no iOS/iPadOS — obrigatória para [SharePlus.instance.share]
/// (retângulo não nulo dentro da view de origem).
///
/// Retorna `null` se o [RenderBox] ainda não tiver layout.
Rect? sharePositionOriginFromContext(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  final origin = box.localToGlobal(Offset.zero) & box.size;
  if (origin.width <= 0 || origin.height <= 0) return null;
  return origin;
}

/// Igual a [sharePositionOriginFromContext], com fallback no centro-inferior
/// da tela quando o widget ainda não tem layout (ex.: item de menu overflow).
Rect sharePositionOriginFromContextOrFallback(BuildContext context) {
  final origin = sharePositionOriginFromContext(context);
  if (origin != null) return origin;

  final size = MediaQuery.sizeOf(context);
  const anchorSize = 48.0;
  return Rect.fromLTWH(
    (size.width - anchorSize) / 2,
    size.height - anchorSize,
    anchorSize,
    anchorSize,
  );
}
