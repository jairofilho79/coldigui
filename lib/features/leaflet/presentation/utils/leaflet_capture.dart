import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/color_extensions.dart';
import '../../domain/entities/leaflet_document.dart';
import '../widgets/leaflet_content.dart';
import '../widgets/leaflet_content_labels.dart';
import 'leaflet_image_capture.dart';

/// Callback injetável para testes — espelha [captureWidgetToPng].
typedef CaptureWidgetToPngFn =
    Future<List<int>> Function(GlobalKey boundaryKey);

const kLeafletPngFileName = 'folheto-plpcg.png';

/// Margem (pt lógico) em volta do folheto no PNG capturado. O WhatsApp iOS
/// apara ~3% da borda direita/inferior de imagem enviada junto com legenda —
/// a margem absorve o aparo e ainda dá fundo opaco aos cantos arredondados
/// (PNG transparente vira preto ao ser convertido em JPEG).
const double kLeafletCaptureMargin = 16.0;

/// Captura [document] off-screen e retorna bytes PNG (UC-08).
///
/// [LeafletContent] fica montado no overlay durante toda a captura — mesmo
/// com [capture] customizado (mock de teste) — para que quem substitui a
/// captura consiga inspecionar o widget realmente montado (ex.: ler
/// `LeafletContent.document` para provar o que foi resolvido).
Future<List<int>> captureLeafletPngBytes(
  OverlayState overlay,
  LeafletDocument document,
  LeafletContentLabels labels, {
  CaptureWidgetToPngFn? capture,
}) async {
  final captureFn = capture ?? captureWidgetToPng;

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
            child: ColoredBox(
              color: AppColors.background,
              child: Padding(
                padding: const EdgeInsets.all(kLeafletCaptureMargin),
                child: LeafletContent(document: document, labels: labels),
              ),
            ),
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
