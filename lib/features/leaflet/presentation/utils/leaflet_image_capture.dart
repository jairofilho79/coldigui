import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'leaflet_debug_log.dart';

/// Aguarda [boundaryKey] ligar a um [RenderRepaintBoundary] pintável.
///
/// Overlay entries podem precisar de mais de um frame antes da captura.
Future<RenderRepaintBoundary> waitForRepaintBoundary(
  GlobalKey boundaryKey, {
  int maxFrames = 10,
}) async {
  for (var frame = 0; frame < maxFrames; frame++) {
    await SchedulerBinding.instance.endOfFrame;
    final boundary = boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary != null && !boundary.debugNeedsPaint) {
      leafletDebugLog(
        'waitForRepaintBoundary: pronto no frame $frame '
        '(size=${boundary.size}, hasSize=${boundary.hasSize})',
      );
      return boundary;
    }
    leafletDebugLog(
      'waitForRepaintBoundary: frame $frame — '
      'boundary=${boundary != null}, '
      'needsPaint=${boundary?.debugNeedsPaint}',
    );
  }

  final last =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (last != null) {
    leafletDebugLog(
      'waitForRepaintBoundary: timeout após $maxFrames frames; '
      'usando boundary com needsPaint=${last.debugNeedsPaint}, size=${last.size}',
    );
    return last;
  }

  leafletDebugLog(
      'waitForRepaintBoundary: boundary ausente após $maxFrames frames');
  throw StateError('RepaintBoundary not found for capture');
}

/// Captura widget em [RepaintBoundary] como PNG (UC-08, Fase 4.6).
///
/// Substitui html2canvas da PWA — sem dependência externa.
///
/// Lança [StateError] se [boundaryKey] não estiver ligado a um
/// [RenderRepaintBoundary] ou se a codificação PNG falhar.
Future<Uint8List> captureWidgetToPng(
  GlobalKey boundaryKey, {
  double pixelRatio = 3.0,
}) async {
  leafletDebugLog('captureWidgetToPng: início (pixelRatio=$pixelRatio)');
  final boundary = await waitForRepaintBoundary(boundaryKey);

  final image = await boundary.toImage(pixelRatio: pixelRatio);
  leafletDebugLog(
    'captureWidgetToPng: toImage OK (${image.width}x${image.height})',
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    leafletDebugLog('captureWidgetToPng: toByteData retornou null');
    throw StateError('Failed to encode leaflet as PNG');
  }

  leafletDebugLog('captureWidgetToPng: PNG ${byteData.lengthInBytes} bytes');
  return byteData.buffer.asUint8List();
}
