import 'reader_fullscreen_platform_native.dart'
    if (dart.library.js_interop) 'reader_fullscreen_platform_web.dart';

/// Porta de fullscreen do leitor (spec A.3 C8).
///
/// Nativo: `SystemChrome` (modo imersivo) — sem stream de eventos do SO.
/// Web: Fullscreen API real do navegador (`Element.requestFullscreen` /
/// `Document.exitFullscreen`), com [changes] espelhando o evento
/// `fullscreenchange` — inclusive quando o usuário sai pelo próprio
/// navegador (Esc do browser), fora do controle do app.
abstract interface class ReaderFullscreenPlatform {
  /// Entra em fullscreen. Na web, exige gesto do usuário (tecla/clique) — sem
  /// gesto o `requestFullscreen` rejeita a Promise.
  Future<void> enter();

  /// Sai do fullscreen.
  Future<void> exit();

  /// Estado real do fullscreen reportado pela plataforma.
  Stream<bool> get changes;
}

/// Factory por plataforma (conditional import).
ReaderFullscreenPlatform createReaderFullscreenPlatform() =>
    createReaderFullscreenPlatformImpl();
