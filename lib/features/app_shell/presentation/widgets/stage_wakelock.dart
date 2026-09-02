import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../audio_player/presentation/providers/audio_player_session_provider.dart';

/// Rotas em que o aparelho fica no atril e a tela não pode apagar.
const _stageRoutes = <String>{
  RoutePaths.reader,
  RoutePaths.chords,
  RoutePaths.audio,
};

/// Decide se a tela deve ficar acesa (C2).
///
/// Vale para as rotas de palco — partitura, cifra e reprodutor — e para
/// qualquer rota enquanto houver áudio tocando: quem deixou um MIDI rodando na
/// Home continua olhando a lista sem o aparelho apagar no meio do ensaio.
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
  bool? _held;

  @override
  void dispose() {
    // O shell só é desmontado no fim do app; ainda assim, não deixar o lock
    // pendurado é mais barato que descobrir a bateria vazia depois.
    if (_held == true) {
      _call(ref.read(stageWakelockProvider), hold: false);
    }
    super.dispose();
  }

  Future<void> _call(
    StageWakelockController controller, {
    required bool hold,
  }) async {
    try {
      if (hold) {
        await controller.enable();
      } else {
        await controller.disable();
      }
    } on Object catch (error) {
      // Na web o lock depende de permissão/gesto do usuário e pode lançar;
      // a tela apagar não justifica derrubar a navegação.
      debugPrint(
        '[StageWakelock] ${hold ? 'enable' : 'disable'} falhou: $error',
      );
    }
  }

  void _sync(bool hold) {
    if (_held == hold) return;
    _held = hold;
    final controller = ref.read(stageWakelockProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _call(controller, hold: hold);
    });
  }

  @override
  Widget build(BuildContext context) {
    final playing = ref.watch(
      audioPlayerSessionProvider.select((session) => session.playing),
    );
    _sync(shouldHoldWakelock(path: widget.path, playing: playing));
    return widget.child;
  }
}
