import 'dart:typed_data';

import 'gesture_figure_store_native.dart'
    if (dart.library.js_interop) 'gesture_figure_store_web.dart';

/// Persistência das figuras PNG/GIF dos gestos, por `r2Key`.
///
/// Espelha `PdfStoragePort` na forma (filesystem no nativo, Cache API na web)
/// mas num store **separado** dos PDFs: as figuras não entram nas
/// estatísticas do UC-10 (`getTotalOfflineBytes`/`listOrphans`), que contam o
/// que o usuário baixou de propósito.
///
/// Best-effort: nenhuma operação lança — figura que não gravou vira download
/// de novo na próxima abertura, nunca erro de tela.
abstract interface class GestureFigureStorePort {
  Future<Uint8List?> read(String r2Key);
  Future<void> write(String r2Key, Uint8List bytes);
  Future<void> deleteAll();
}

/// Subdiretório (nativo) / prefixo lógico (web) do store.
const kGestureFigureStoreSubdir = 'plpcg_gestures/figures';

/// Nome de arquivo estável e seguro para [r2Key].
///
/// `assets/cia/gestures/c687580e7682.png` → `assets_cia_gestures_c687580e7682.png`.
/// Não é hash de propósito: dá para achar a figura no disco pelo id.
String gestureFigureFileName(String r2Key) =>
    r2Key.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

/// Factory por plataforma (import condicional).
GestureFigureStorePort createGestureFigureStore() =>
    createGestureFigureStoreImpl();
