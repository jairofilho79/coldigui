/// Chave de desligar do atalho de `ImageBitmap` na web (patch local do
/// pdfrx, ver `third_party/pdfrx/PATCH.md` no app).
///
/// Sem import de plataforma de propósito: é lida tanto do código
/// compartilhado (`pdfrx_flutter.dart`) quanto do implementação WASM
/// (`wasm/pdfrx_wasm.dart`, web-only), e dá para alternar em teste ou em
/// campo sem precisar de um novo build condicional.
abstract final class PdfrxWebImagePath {
  /// `true`: pede um `ImageBitmap` já pronto ao worker (renderPage) e, ao
  /// montar o `ui.Image`, entrega esse bitmap direto ao engine
  /// (`dart:ui_web`), sem o BMP montado pixel a pixel. `false` restaura
  /// 100% o caminho anterior do pdfrx 2.6.1, inclusive não pedindo o
  /// bitmap ao worker — é a válvula de emergência.
  static bool useImageBitmap = true;
}
