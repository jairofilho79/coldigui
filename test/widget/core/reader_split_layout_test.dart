import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/presentation/widgets/reader_split_layout.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fixa o leitor em fullscreen sem montar a assinatura de plataforma real
/// (spec A.3 C8) — só o que este teste precisa.
class _FullscreenFixedNotifier extends ReaderFullscreenNotifier {
  @override
  bool build() => true;
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  bool panelOpen = true,
  bool fullscreen = false,
}) async {
  SharedPreferences.setMockInitialValues({
    StorageKeys.readerSidePanelOpen: panelOpen,
  });
  final prefs = await SharedPreferences.getInstance();

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (fullscreen)
          readerFullscreenProvider.overrideWith(_FullscreenFixedNotifier.new),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ReaderSplitLayout(
            panel: Text('painel-lateral'),
            child: Text('conteudo-leitor'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tela larga + painel aberto mostra o painel', (tester) async {
    await _pump(tester, size: const Size(1200, 800));

    expect(find.text('painel-lateral'), findsOneWidget);
    expect(find.text('conteudo-leitor'), findsOneWidget);
  });

  testWidgets('tela larga + painel fechado esconde o painel', (tester) async {
    await _pump(tester, size: const Size(1200, 800), panelOpen: false);

    expect(find.text('painel-lateral'), findsNothing);
    expect(find.text('conteudo-leitor'), findsOneWidget);
  });

  testWidgets('tela estreita esconde o painel mesmo aberto', (tester) async {
    await _pump(tester, size: const Size(600, 800));

    expect(find.text('painel-lateral'), findsNothing);
    expect(find.text('conteudo-leitor'), findsOneWidget);
  });

  testWidgets('fullscreen esconde o painel mesmo largo e aberto', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1200, 800), fullscreen: true);

    expect(find.text('painel-lateral'), findsNothing);
    expect(find.text('conteudo-leitor'), findsOneWidget);
  });
}
