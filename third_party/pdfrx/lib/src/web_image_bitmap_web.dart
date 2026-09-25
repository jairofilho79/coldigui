import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;

import 'package:pdfrx_engine/pdfrx_engine.dart';

import 'utils/web_image_path.dart';
import 'wasm/pdfrx_wasm.dart';

/// Caminho rápido do patch local (ver `PATCH.md`): se [image] carrega um
/// `ImageBitmap` pronto do worker, entrega-o direto ao engine via
/// `dart:ui_web` (~0,1 ms) em vez do caminho por BMP do pdfrx 2.6.1
/// (`ImageDescriptor.raw` — 120–240 ms numa página A4 no Chrome).
///
/// `null` faz [PdfImageExt.createImage] cair no caminho comum: chave
/// [PdfrxWebImagePath.useImageBitmap] desligada, imagem sem bitmap (o
/// worker não devolveu um — alpha premultiplicado ou `createImageBitmap`
/// ausente), ou [pixelSizeThreshold] pedindo downscale (só o caminho por
/// BMP faz isso, via `targetWidth`/`targetHeight` do `Codec`).
Future<ui.Image?> tryCreateImageFromBitmap(PdfImage image, {int? pixelSizeThreshold}) async {
  if (!PdfrxWebImagePath.useImageBitmap) return null;
  if (pixelSizeThreshold != null) return null;
  if (image is! PdfImageWeb) return null;
  final bitmap = image.takeBitmapForFlutter();
  if (bitmap == null) return null;
  return await ui_web.createImageFromImageBitmap(bitmap);
}
