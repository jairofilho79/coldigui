import 'package:coldigui/features/autoscroll/presentation/widgets/autoscroll_speed_slider_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/pump_app.dart';

void main() {
  testWidgets('AutoscrollSpeedSliderBar exibe Lento, Rápido e Slider magnético', (
    tester,
  ) async {
    int? changedSpeed;
    var closed = false;

    await pumpApp(
      tester,
      Scaffold(
        body: AutoscrollSpeedSliderBar(
          speed: 8,
          onSpeedChanged: (speed) => changedSpeed = speed,
          onClose: () => closed = true,
        ),
      ),
    );
    await tester.pump();

    // Rótulos
    expect(find.text('Lento'), findsOneWidget);
    expect(find.text('Rápido'), findsOneWidget);

    // Não exibe texto cru 1x, 2x, etc.
    expect(find.text('8x'), findsNothing);
    expect(find.text('1x'), findsNothing);

    // Slider discreto com 14 divisões entre 1 e 15, centrado no meio (8)
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 1.0);
    expect(slider.max, 15.0);
    expect(slider.divisions, 14);
    expect(slider.value, 8.0);

    // Ajuste no slider aciona callback
    slider.onChanged?.call(12.0);
    expect(changedSpeed, 12);

    // Fechar aciona callback
    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    expect(closed, isTrue);
  });
}
