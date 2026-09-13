import 'package:coldigui/core/theme/app_theme.dart';
import 'package:coldigui/core/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tela que limpa snackbars ao montar — o que os leitores fazem (P8).
class _ClearingScreen extends StatefulWidget {
  const _ClearingScreen();

  @override
  State<_ClearingScreen> createState() => _ClearingScreenState();
}

class _ClearingScreenState extends State<_ClearingScreen> {
  @override
  void initState() {
    super.initState();
    clearSnackbarsOnEnter(context);
  }

  @override
  Widget build(BuildContext context) => const Text('leitor');
}

Future<void> _pumpApp(WidgetTester tester, {required double width}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () => showAppSnackbar(context, 'Olá'),
                child: const Text('mostrar'),
              ),
              TextButton(
                onPressed: () => showAppSnackbar(
                  context,
                  'Com ação',
                  action: SnackBarAction(label: 'Trocar', onPressed: () {}),
                  clearPrevious: true,
                ),
                child: const Text('com ação'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: _ClearingScreen()),
                  ),
                ),
                child: const Text('abrir leitor'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  test(
    'appSnackbarWidth limita a 480 em tela larga e a largura-32 em tela estreita',
    () {
      expect(appSnackbarWidth(1600), kAppSnackbarMaxWidth);
      expect(appSnackbarWidth(400), 368);
    },
  );

  testWidgets('showAppSnackbar flutua com largura máxima em tela larga (P8)', (
    tester,
  ) async {
    await _pumpApp(tester, width: 1600);
    await tester.tap(find.text('mostrar'));
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.width, kAppSnackbarMaxWidth);
  });

  testWidgets('showAppSnackbar cabe em tela estreita', (tester) async {
    await _pumpApp(tester, width: 400);
    await tester.tap(find.text('mostrar'));
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.width, 368);
    expect(tester.takeException(), isNull);
  });

  testWidgets('action e clearPrevious substituem o snackbar anterior', (
    tester,
  ) async {
    await _pumpApp(tester, width: 1600);
    await tester.tap(find.text('mostrar'));
    await tester.pump();
    await tester.tap(find.text('com ação'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Olá'), findsNothing);
    expect(find.text('Com ação'), findsOneWidget);
    expect(find.text('Trocar'), findsOneWidget);
  });

  testWidgets('clearSnackbarsOnEnter remove o snackbar ao montar a tela', (
    tester,
  ) async {
    await _pumpApp(tester, width: 1600);
    await tester.tap(find.text('mostrar'));
    await tester.pump();
    expect(find.text('Olá'), findsOneWidget);

    await tester.tap(find.text('abrir leitor'));
    await tester.pumpAndSettle();

    expect(find.text('leitor'), findsOneWidget);
    expect(find.text('Olá'), findsNothing);
  });

  test('tema do app usa snackbar flutuante por padrão', () {
    expect(AppTheme.light.snackBarTheme.behavior, SnackBarBehavior.floating);
  });
}
