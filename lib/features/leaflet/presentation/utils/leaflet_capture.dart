import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/leaflet_document.dart';
import '../widgets/leaflet_content.dart';
import '../widgets/leaflet_content_labels.dart';
import 'leaflet_image_capture.dart';

/// Callback injetável para testes — espelha [captureWidgetToPng].
typedef CaptureWidgetToPngFn = Future<List<int>> Function(
  GlobalKey boundaryKey,
);

/// Callback injetável para testes — espelha [path_provider.getTemporaryDirectory].
typedef GetTemporaryDirectoryFn = Future<Directory> Function();

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

/// Grava [pngBytes] em arquivo temporário do folheto.
Future<File> writeLeafletPngToTempFile(
  List<int> pngBytes, {
  GetTemporaryDirectoryFn getTemporaryDirectory =
      path_provider.getTemporaryDirectory,
}) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/$kLeafletPngFileName');
  await file.writeAsBytes(pngBytes, flush: true);
  return file;
}

/// [XFile] do folheto a partir de [file] em disco.
XFile leafletXFileFromFile(File file) {
  return XFile(
    file.path,
    mimeType: 'image/png',
    name: kLeafletPngFileName,
  );
}
