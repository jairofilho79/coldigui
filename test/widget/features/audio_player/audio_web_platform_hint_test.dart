import 'package:coldigui/features/audio_player/presentation/widgets/audio_web_platform_hint.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHint(WidgetTester tester, {required String message}) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Scaffold(
          body: Stack(children: [AudioWebPlatformHint(message: message)]),
        ),
      ),
    );
  }

  testWidgets('ícone revela e esconde o aviso ao toque', (tester) async {
    const message = 'aviso de segundo plano';
    await pumpHint(tester, message: message);

    expect(find.text(message), findsNothing);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pump();

    expect(find.text(message), findsOneWidget);
    expect(find.byIcon(Icons.info), findsOneWidget);

    await tester.tap(find.byIcon(Icons.info));
    await tester.pump();

    expect(find.text(message), findsNothing);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });
}
