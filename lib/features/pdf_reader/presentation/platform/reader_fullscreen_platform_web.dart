import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'reader_fullscreen_platform.dart';

ReaderFullscreenPlatform createReaderFullscreenPlatformImpl() =>
    _WebReaderFullscreenPlatform();

/// Web: Fullscreen API real do navegador — `documentElement.requestFullscreen()`
/// / `document.exitFullscreen()`, escutando `fullscreenchange` para refletir
/// saídas fora do controle do app (Esc do browser).
class _WebReaderFullscreenPlatform implements ReaderFullscreenPlatform {
  @override
  Future<void> enter() async {
    await web.document.documentElement!.requestFullscreen().toDart;
  }

  @override
  Future<void> exit() async {
    // Minor (onda 4): sem guarda, um `exit()` chamado quando o navegador
    // nunca entrou de fato em fullscreen (ex.: `enter()` rejeitado por falta
    // de gesto do usuário — ver docstring de [ReaderFullscreenPlatform.enter])
    // rejeita a Promise do `exitFullscreen()` a cada saída, gerando um warn
    // à toa.
    if (web.document.fullscreenElement == null) return;
    await web.document.exitFullscreen().toDart;
  }

  @override
  Stream<bool> get changes => web.EventStreamProviders.fullscreenChangeEvent
      .forTarget(web.document)
      .map((_) => web.document.fullscreenElement != null);
}
