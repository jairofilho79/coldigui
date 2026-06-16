import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'leaflet_debug_log.dart';

/// [debugNeedsPaint] só existe em debug — em profile/release lança
/// [LateInitializationError] (visto no iPad, build homolog).
bool _repaintBoundaryReady(RenderRepaintBoundary boundary) {
  if (!boundary.hasSize) return false;
  final size = boundary.size;
  if (size.width <= 0 || size.height <= 0) return false;
  if (kDebugMode) {
    return !boundary.debugNeedsPaint;
  }
  return true;
}

String _boundaryStatus(RenderRepaintBoundary? boundary) {
  if (boundary == null) return 'boundary=false';
  final size = boundary.hasSize ? boundary.size : Size.zero;
  if (kDebugMode) {
    return 'boundary=true, needsPaint=${boundary.debugNeedsPaint}, size=$size';
  }
  return 'boundary=true, hasSize=${boundary.hasSize}, size=$size';
}

/// Aguarda [boundaryKey] ligar a um [RenderRepaintBoundary] pintável.
///
/// Overlay entries podem precisar de mais de um frame antes da captura.
Future<RenderRepaintBoundary> waitForRepaintBoundary(
  GlobalKey boundaryKey, {
  int maxFrames = 10,
  int releaseSettleFrames = 2,
}) async {
  RenderRepaintBoundary? ready;

  for (var frame = 0; frame < maxFrames; frame++) {
    await SchedulerBinding.instance.endOfFrame;
    final boundary = boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary != null && _repaintBoundaryReady(boundary)) {
      ready = boundary;
      leafletDebugLog(
        'waitForRepaintBoundary: pronto no frame $frame '
        '(size=${boundary.size}, hasSize=${boundary.hasSize})',
      );
      break;
    }
    leafletDebugLog(
      'waitForRepaintBoundary: frame $frame — ${_boundaryStatus(boundary)}',
    );
  }

  if (ready != null) {
    if (!kDebugMode) {
      for (var i = 0; i < releaseSettleFrames; i++) {
        await SchedulerBinding.instance.endOfFrame;
      }
      leafletDebugLog(
        'waitForRepaintBoundary: settle profile/release '
        '($releaseSettleFrames frames extras)',
      );
    }
    return ready;
  }

  final last =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (last != null) {
    leafletDebugLog(
      'waitForRepaintBoundary: timeout após $maxFrames frames; '
      'usando boundary (${_boundaryStatus(last)})',
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
