import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/app_shell/presentation/widgets/stage_wakelock.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registra as chamadas em vez de falar com o plugin.
class _RecordingWakelock implements StageWakelockController {
  _RecordingWakelock({this.failEnable = false});

  final bool failEnable;
  final calls = <String>[];

  @override
  Future<void> enable() async {
    calls.add('enable');
    if (failEnable) throw StateError('sem permissão');
  }

  @override
  Future<void> disable() async => calls.add('disable');
}

/// Sessão de áudio de mentira: o `build` da sessão real cria um `AudioPlayer`.
class _FakeAudioSession extends AudioPlayerSessionNotifier {
  @override
  AudioPlayerSessionState build() => const AudioPlayerSessionState();
}

Future<void> _pump(
  WidgetTester tester, {
  required String path,
  required _RecordingWakelock wakelock,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        stageWakelockProvider.overrideWithValue(wakelock),
        audioPlayerSessionProvider.overrideWith(_FakeAudioSession.new),
      ],
      child: MaterialApp(
        home: StageWakelockListener(path: path, child: const SizedBox.shrink()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('rota fora do palco não chama o plugin na abertura', (
    tester,
  ) async {
    final wakelock = _RecordingWakelock();

    await _pump(tester, path: RoutePaths.home, wakelock: wakelock);

    // Sem lock para soltar: um `disable()` de partida só carregaria o
    // `no_sleep.js` na web à toa.
    expect(wakelock.calls, isEmpty);
  });

  testWidgets('rota de palco segura a tela e solta no dispose', (tester) async {
    final wakelock = _RecordingWakelock();

    await _pump(tester, path: RoutePaths.reader, wakelock: wakelock);
    expect(wakelock.calls, ['enable']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(wakelock.calls, ['enable', 'disable']);
  });

  testWidgets('enable que falha não fica marcado como aplicado', (
    tester,
  ) async {
    final wakelock = _RecordingWakelock(failEnable: true);

    await _pump(tester, path: RoutePaths.reader, wakelock: wakelock);
    expect(wakelock.calls, ['enable']);

    // O próximo build tenta de novo — e o dispose não solta um lock que nunca
    // chegou a existir.
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(wakelock.calls, isNot(contains('disable')));
  });
}
