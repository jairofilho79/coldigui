import 'package:coldigui/features/audio_player/presentation/widgets/audio_transport_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('sem callbacks de ±10 s, os botões não aparecem', (tester) async {
    await tester.pumpWidget(
      wrap(
        AudioTransportControls(
          playing: false,
          buffering: false,
          hasPrevious: false,
          hasNext: false,
          onPrevious: () {},
          onPlayPause: () {},
          onNext: () {},
          playTooltip: 'Reproduzir',
          pauseTooltip: 'Pausar',
          previousTooltip: 'Anterior',
          nextTooltip: 'Próximo',
        ),
      ),
    );

    expect(find.byIcon(Icons.replay_10), findsNothing);
    expect(find.byIcon(Icons.forward_10), findsNothing);
  });

  testWidgets('com callbacks, ±10 s aparecem e chamam o retorno certo', (
    tester,
  ) async {
    var back = 0;
    var forward = 0;
    await tester.pumpWidget(
      wrap(
        AudioTransportControls(
          playing: true,
          buffering: false,
          hasPrevious: true,
          hasNext: true,
          onPrevious: () {},
          onPlayPause: () {},
          onNext: () {},
          onSeekBack10: () => back++,
          onSeekForward10: () => forward++,
          seekBack10Tooltip: 'Voltar 10 s',
          seekForward10Tooltip: 'Avançar 10 s',
          playTooltip: 'Reproduzir',
          pauseTooltip: 'Pausar',
          previousTooltip: 'Anterior',
          nextTooltip: 'Próximo',
        ),
      ),
    );

    expect(find.byIcon(Icons.replay_10), findsOneWidget);
    expect(find.byIcon(Icons.forward_10), findsOneWidget);

    await tester.tap(find.byIcon(Icons.replay_10));
    await tester.tap(find.byIcon(Icons.forward_10));
    await tester.pump();

    expect(back, 1);
    expect(forward, 1);
  });

  testWidgets('tooltips dos botões de ±10 s', (tester) async {
    await tester.pumpWidget(
      wrap(
        AudioTransportControls(
          playing: false,
          buffering: false,
          hasPrevious: false,
          hasNext: false,
          onPrevious: () {},
          onPlayPause: () {},
          onNext: () {},
          onSeekBack10: () {},
          onSeekForward10: () {},
          seekBack10Tooltip: 'Voltar 10 s',
          seekForward10Tooltip: 'Avançar 10 s',
          playTooltip: 'Reproduzir',
          pauseTooltip: 'Pausar',
          previousTooltip: 'Anterior',
          nextTooltip: 'Próximo',
        ),
      ),
    );

    expect(find.byTooltip('Voltar 10 s'), findsOneWidget);
    expect(find.byTooltip('Avançar 10 s'), findsOneWidget);
  });
}
