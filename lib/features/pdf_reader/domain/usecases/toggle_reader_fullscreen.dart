/// UC-11 — Toggle fullscreen do leitor (oculta barras 1–3, PDF em tela cheia).
///
/// Estado em [readerFullscreenProvider]; UI em [ShellScaffold] e
/// [PdfReaderScreen]._ReaderScaffold.
class ToggleReaderFullscreen {
  const ToggleReaderFullscreen(this._toggle);

  final Future<void> Function() _toggle;

  /// Alterna fullscreen — delega [ReaderFullscreenNotifier.toggle].
  Future<void> call() => _toggle();
}
