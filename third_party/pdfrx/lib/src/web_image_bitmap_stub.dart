import 'dart:ui';

import 'package:pdfrx_engine/pdfrx_engine.dart';

/// Fora da web não há `ImageBitmap`/`dart:ui_web`: sempre `null`, o
/// chamador ([PdfImageExt.createImage]) cai no caminho comum (`pixels` +
/// `ImageDescriptor.raw`).
Future<Image?> tryCreateImageFromBitmap(PdfImage image, {int? pixelSizeThreshold}) async => null;
