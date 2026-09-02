import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/app_shell/presentation/widgets/app_shortcuts.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Alvo de foco neutro: sem ele o evento de tecla não tem por onde subir até
/// os atalhos globais.
const _stage = Focus(autofocus: true, child: SizedBox.expand());

Future<ProviderContainer> _pumpShortcuts(
  WidgetTester tester, {
  required String path,
  Widget child = _stage,
}) async {
  final router = GoRouter(
    initialLocation: path,
    routes: [
      for (final route in {path, RoutePaths.home})
        GoRoute(
          path: route,
          builder: (_, _) => Scaffold(
            body: AppShortcuts(path: route, child: child),
          ),
        ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return ProviderScope.containerOf(tester.element(find.byType(AppShortcuts)));
}

void main() {
  testWidgets('F no leitor liga a tela cheia', (tester) async {
    final container = await _pumpShortcuts(tester, path: RoutePaths.reader);
    expect(container.read(readerFullscreenProvider), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();

    expect(container.read(readerFullscreenProvider), isTrue);
  });

  testWidgets('F no leitor de cifras também liga a tela cheia', (tester) async {
    final container = await _pumpShortcuts(tester, path: RoutePaths.chords);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();

    expect(container.read(readerFullscreenProvider), isTrue);
  });

  testWidgets('F fora do leitor não mexe na tela cheia', (tester) async {
    final container = await _pumpShortcuts(tester, path: RoutePaths.home);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();

    expect(container.read(readerFullscreenProvider), isFalse);
  });

  testWidgets('Esc sai da tela cheia', (tester) async {
    final container = await _pumpShortcuts(tester, path: RoutePaths.reader);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(container.read(readerFullscreenProvider), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(container.read(readerFullscreenProvider), isFalse);
  });

  testWidgets('/ pede foco na busca', (tester) async {
    final container = await _pumpShortcuts(tester, path: RoutePaths.home);
    final before = container.read(searchFocusRequestProvider);

    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pumpAndSettle();

    expect(container.read(searchFocusRequestProvider), before + 1);
  });

  testWidgets('Ctrl+K pede foco na busca a partir do leitor', (tester) async {
    final container = await _pumpShortcuts(tester, path: RoutePaths.reader);
    final before = container.read(searchFocusRequestProvider);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(container.read(searchFocusRequestProvider), before + 1);
  });

  testWidgets('tecla seca não dispara com o foco num campo de texto', (
    tester,
  ) async {
    final container = await _pumpShortcuts(
      tester,
      path: RoutePaths.reader,
      child: const TextField(autofocus: true),
    );

    // `/` e `F` são caracteres válidos numa busca — o atalho tem que calar.
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();

    expect(container.read(searchFocusRequestProvider), 0);
    expect(container.read(readerFullscreenProvider), isFalse);
  });
}
