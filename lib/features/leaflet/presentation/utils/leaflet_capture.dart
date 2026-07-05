import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/leaflet_document.dart';
import '../widgets/leaflet_content.dart';
import '../widgets/leaflet_content_labels.dart';
import 'leaflet_image_capture.dart';

/// Callback injetável para testes — espelha [captureWidgetToPng].
typedef CaptureWidgetToPngFn =
    Future<List<int>> Function(GlobalKey boundaryKey);

const kLeafletPngFileName = 'folheto-plpcg.png';

/// Captura [document] off-screen e retorna bytes PNG (UC-08).
///
/// Com [capture] customizado, pula overlay — útil em testes com mock.
Future<List<int>> captureLeafletPngBytes(
  OverlayState overlay,
  LeafletDocument document,
  LeafletContentLabels labels, {
  CaptureWidgetToPngFn? capture,
}) async {
  final captureFn = capture ?? captureWidgetToPng;
  if (capture != null) {
    return captureFn(GlobalKey());
  }

  final boundaryKey = GlobalKey();
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 0,
      top: 0,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.01,
          child: RepaintBoundary(
            key: boundaryKey,
            child: LeafletContent(document: document, labels: labels),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  try {
    return await captureFn(boundaryKey);
  } finally {
    entry.remove();
  }
}

/// [XFile] do folheto a partir de bytes PNG (D4 OA — sem temp file).
XFile leafletXFileFromBytes(List<int> pngBytes) {
  return XFile.fromData(
    Uint8List.fromList(pngBytes),
    mimeType: 'image/png',
    name: kLeafletPngFileName,
  );
}
