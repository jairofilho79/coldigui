import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/toggle_reader_fullscreen.dart';

/// UC-11 — Modo fullscreen do leitor (oculta barras 1–3).
final readerFullscreenProvider =
    NotifierProvider<ReaderFullscreenNotifier, bool>(
  ReaderFullscreenNotifier.new,
);

/// Use case UC-11 — fullscreen do leitor (oculta barras 1–3).
final toggleReaderFullscreenProvider = Provider<ToggleReaderFullscreen>((ref) {
  return ToggleReaderFullscreen(
    () => ref.read(readerFullscreenProvider.notifier).toggle(),
  );
});

/// Controla visibilidade das barras 1–3 do leitor e overlays do sistema.
///
/// Consumido por [ShellScaffold] (barras 1–2) e [PdfReaderScreen] (barra 3 +
/// FAB). Ao alternar, [PdfReaderScreen] reaplica fit pós-frame — ver
/// `_scheduleApplyInitialFit`.
class ReaderFullscreenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Alterna entre modo normal e fullscreen (barras ocultas + immersive UI).
  Future<void> toggle() async {
    await _setFullscreen(!state);
  }

  /// Sai do fullscreen sem alternar — usado ao navegar para fora de `/leitor`.
  Future<void> exit() async {
    if (!state) return;
    await _setFullscreen(false);
  }

  Future<void> _setFullscreen(bool enabled) async {
    state = enabled;
    if (enabled) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
  }
}
