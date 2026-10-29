import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../audio_player/presentation/providers/audio_player_session_provider.dart';

/// Rotas em que o aparelho fica no atril e a tela não pode apagar.
const _stageRoutes = <String>{
  RoutePaths.reader,
  RoutePaths.chords,
  RoutePaths.gestos,
  RoutePaths.audio,
};

/// Decide se a tela deve ficar acesa (C2).
///
/// Vale para as rotas de palco — partitura, cifra, gestos e reprodutor — e
/// para qualquer rota enquanto houver áudio tocando: quem deixou um MIDI
/// rodando na Home continua olhando a lista sem o aparelho apagar no meio do
/// ensaio.
bool shouldHoldWakelock({required String path, required bool playing}) {
  if (playing) return true;
  return _stageRoutes.contains(path);
}

/// Ponte para o `wakelock_plus`, isolada para os testes de widget.
abstract interface class StageWakelockController {
  Future<void> enable();
  Future<void> disable();
}

class WakelockPlusStageWakelock implements StageWakelockController {
  const WakelockPlusStageWakelock();

  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}

final stageWakelockProvider = Provider<StageWakelockController>(
  (ref) => const WakelockPlusStageWakelock(),
);

/// Mantém a tela ligada nas rotas de palco (C2) — montado no [ShellScaffold].
///
/// Só chama o plugin quando o resultado de [shouldHoldWakelock] muda, para não
/// repetir a chamada de plataforma a cada rebuild do shell.
class StageWakelockListener extends ConsumerStatefulWidget {
  const StageWakelockListener({
    required this.path,
    required this.child,
    super.key,
  });

  /// Caminho da rota atual do shell.
  final String path;

  final Widget child;

  @override
  ConsumerState<StageWakelockListener> createState() =>
      _StageWakelockListenerState();
}

class _StageWakelockListenerState extends ConsumerState<StageWakelockListener> {
  /// O que o plugin tem hoje — não o que se quer que ele tenha.
  ///
  /// Começa em `false` (o app abre sem lock): se começasse em `null`, o
  /// primeiro build fora das rotas de palco veria `null != false` e dispararia
  /// um `disable()` inútil — que na web ainda carrega o `no_sleep.js` à toa.
  /// E só vira `true`/`false` depois de a chamada de plataforma dar certo, para
  /// que um `enable()` que falhou seja tentado de novo no próximo build em vez
  /// de ficar marcado como aplicado.
  bool _held = false;

  /// Último valor pedido pelo `build`.
  bool _target = false;

  bool _syncing = false;

  /// Controlador guardado no `build`.
  ///
  /// `ref.read` no `dispose` **lança** ("Using ref when a widget is about to or
  /// has been unmounted is unsafe"), então o lock nunca era solto na saída —
  /// justamente o caso que o `dispose` existe para cobrir. Guardar a instância
  /// resolve; o `try/catch` de [_call] cuida do resto.
  StageWakelockController? _controller;

  @override
  void dispose() {
    // O shell só é desmontado no fim do app; ainda assim, não deixar o lock
    // pendurado é mais barato que descobrir a bateria vazia depois.
    final controller = _controller;
    if (_held && controller != null) {
      _call(controller, hold: false);
    }
    super.dispose();
  }

  /// `true` quando a chamada de plataforma foi até o fim.
  Future<bool> _call(
    StageWakelockController controller, {
    required bool hold,
  }) async {
    try {
      if (hold) {
        await controller.enable();
      } else {
        await controller.disable();
      }
      return true;
    } on Object catch (error) {
      // Na web o lock depende de permissão/gesto do usuário e pode lançar;
      // a tela apagar não justifica derrubar a navegação.
      debugPrint(
        '[StageWakelock] ${hold ? 'enable' : 'disable'} falhou: $error',
      );
      return false;
    }
  }

  void _sync(bool hold) {
    _target = hold;
    if (_syncing || _held == hold) return;
    _syncing = true;
    final controller = _controller!;
    WidgetsBinding.instance.addPostFrameCallback((_) => _drain(controller));
  }

  /// Persegue [_target] até alcançá-lo, uma chamada por vez.
  ///
  /// Uma troca de rota durante o `await` não se perde (o laço relê o alvo) e
  /// duas chamadas de plataforma nunca ficam em voo ao mesmo tempo.
  Future<void> _drain(StageWakelockController controller) async {
    while (mounted && _held != _target) {
      final hold = _target;
      if (!await _call(controller, hold: hold)) break;
      _held = hold;
    }
    _syncing = false;
  }

  @override
  Widget build(BuildContext context) {
    _controller = ref.watch(stageWakelockProvider);
    final playing = ref.watch(
      audioPlayerSessionProvider.select((session) => session.playing),
    );
    _sync(shouldHoldWakelock(path: widget.path, playing: playing));
    return widget.child;
  }
}
