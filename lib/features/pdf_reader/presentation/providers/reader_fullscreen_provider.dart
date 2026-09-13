import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../domain/usecases/toggle_reader_fullscreen.dart';
import '../platform/reader_fullscreen_platform.dart';

final _log = AppLogger.of('pdf_reader');

/// Porta de fullscreen do leitor (spec A.3 C8) — sobreescrevível nos testes.
final readerFullscreenPlatformProvider = Provider<ReaderFullscreenPlatform>(
  (_) => createReaderFullscreenPlatform(),
);

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
///
/// Na web, [ReaderFullscreenPlatform.changes] pode desligar o estado sozinho
/// quando o usuário sai do fullscreen pelo próprio navegador (Esc do
/// browser) — nesse caso o notifier só reflete o estado, sem chamar
/// [ReaderFullscreenPlatform.exit] de novo (o navegador já saiu).
class ReaderFullscreenNotifier extends Notifier<bool> {
  StreamSubscription<bool>? _platformSubscription;

  @override
  bool build() {
    final platform = ref.watch(readerFullscreenPlatformProvider);
    _platformSubscription?.cancel();
    _platformSubscription = platform.changes.listen(_onPlatformChange);
    ref.onDispose(() {
      _platformSubscription?.cancel();
      _platformSubscription = null;
    });
    return false;
  }

  void _onPlatformChange(bool isFullscreen) {
    if (!isFullscreen && state) {
      state = false;
    }
  }

  /// Alterna entre modo normal e fullscreen (barras ocultas + immersive UI).
  Future<void> toggle() async {
    await _setFullscreen(!state);
  }

  /// Sai do fullscreen sem alternar — usado ao navegar para fora de `/leitor`.
  Future<void> exit() async {
    if (!state) return;
    await _setFullscreen(false);
  }

  /// Modo imersivo do app (`state`) é otimista: liga/desliga antes de chamar
  /// a plataforma e **não** desfaz em caso de falha — na web, um
  /// `requestFullscreen` sem gesto do usuário rejeita a Promise, mas o app
  /// continua "em fullscreen" (barras ocultas) mesmo que o navegador não
  /// tenha entrado de verdade; a falha só é registrada.
  Future<void> _setFullscreen(bool enabled) async {
    state = enabled;
    final platform = ref.read(readerFullscreenPlatformProvider);
    try {
      if (enabled) {
        await platform.enter();
      } else {
        await platform.exit();
      }
    } on Object catch (error) {
      _log.warn(
        'falha ao ${enabled ? "entrar em" : "sair de"} fullscreen',
        error,
      );
    }
  }
}
