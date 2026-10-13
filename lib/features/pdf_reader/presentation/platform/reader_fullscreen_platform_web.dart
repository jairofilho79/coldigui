import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'reader_fullscreen_platform.dart';

ReaderFullscreenPlatform createReaderFullscreenPlatformImpl() =>
    _WebReaderFullscreenPlatform();

/// Web: Fullscreen API real do navegador — `documentElement.requestFullscreen()`
/// / `document.exitFullscreen()`, escutando `fullscreenchange` e
/// `webkitfullscreenchange` para refletir saídas fora do controle do app (Esc).
///
/// Suporta navegadores modernos e Safari no macOS/iOS (com prefixos
/// `webkitRequestFullscreen`, `webkitExitFullscreen`, `webkitFullscreenElement`).
class _WebReaderFullscreenPlatform implements ReaderFullscreenPlatform {
  bool _isDocumentFullscreen() {
    if (web.document.fullscreenElement != null) return true;
    try {
      final doc = web.document as JSObject;
      final webkitElement = doc['webkitFullscreenElement'];
      if (webkitElement != null && !webkitElement.isUndefinedOrNull) return true;
      final webkitCurrent = doc['webkitCurrentFullScreenElement'];
      if (webkitCurrent != null && !webkitCurrent.isUndefinedOrNull) return true;
    } on Object catch (_) {}
    return false;
  }

  @override
  Future<void> enter() async {
    final element = web.document.documentElement;
    if (element == null) return;
    final jsElement = element as JSObject;

    if (jsElement.has('requestFullscreen')) {
      try {
        final res = jsElement.callMethod('requestFullscreen'.toJS);
        if (res != null && !res.isUndefinedOrNull && res.isA<JSPromise>()) {
          await (res as JSPromise).toDart;
        }
        return;
      } on Object catch (_) {}
    }

    if (jsElement.has('webkitRequestFullscreen')) {
      try {
        final res = jsElement.callMethod('webkitRequestFullscreen'.toJS);
        if (res != null && !res.isUndefinedOrNull && res.isA<JSPromise>()) {
          await (res as JSPromise).toDart;
        }
        return;
      } on Object catch (_) {}
    }

    if (jsElement.has('webkitRequestFullScreen')) {
      try {
        final res = jsElement.callMethod('webkitRequestFullScreen'.toJS);
        if (res != null && !res.isUndefinedOrNull && res.isA<JSPromise>()) {
          await (res as JSPromise).toDart;
        }
        return;
      } on Object catch (_) {}
    }
  }

  @override
  Future<void> exit() async {
    if (!_isDocumentFullscreen()) return;

    final doc = web.document as JSObject;

    if (doc.has('exitFullscreen')) {
      try {
        final res = doc.callMethod('exitFullscreen'.toJS);
        if (res != null && !res.isUndefinedOrNull && res.isA<JSPromise>()) {
          await (res as JSPromise).toDart;
        }
        return;
      } on Object catch (_) {}
    }

    if (doc.has('webkitExitFullscreen')) {
      try {
        final res = doc.callMethod('webkitExitFullscreen'.toJS);
        if (res != null && !res.isUndefinedOrNull && res.isA<JSPromise>()) {
          await (res as JSPromise).toDart;
        }
        return;
      } on Object catch (_) {}
    }

    if (doc.has('webkitCancelFullScreen')) {
      try {
        final res = doc.callMethod('webkitCancelFullScreen'.toJS);
        if (res != null && !res.isUndefinedOrNull && res.isA<JSPromise>()) {
          await (res as JSPromise).toDart;
        }
        return;
      } on Object catch (_) {}
    }
  }

  @override
  Stream<bool> get changes {
    late final StreamController<bool> controller;
    StreamSubscription<web.Event>? sub1;
    StreamSubscription<web.Event>? sub2;

    void onEvent(web.Event _) {
      if (!controller.isClosed) {
        controller.add(_isDocumentFullscreen());
      }
    }

    controller = StreamController<bool>.broadcast(
      onListen: () {
        sub1 = const web.EventStreamProvider<web.Event>('fullscreenchange')
            .forTarget(web.document, useCapture: true)
            .listen(onEvent);
        sub2 = const web.EventStreamProvider<web.Event>('webkitfullscreenchange')
            .forTarget(web.document, useCapture: true)
            .listen(onEvent);
      },
      onCancel: () {
        sub1?.cancel();
        sub2?.cancel();
      },
    );

    return controller.stream;
  }
}


