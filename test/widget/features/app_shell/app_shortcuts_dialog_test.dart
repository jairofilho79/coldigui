import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/app_shell/presentation/widgets/app_shortcuts.dart';
import 'package:coldigui/features/app_shell/presentation/widgets/app_shortcuts_dialog.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _buildTestApp({Widget? child}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('pt'),
    home: Scaffold(
      body: child ??
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAppShortcutsDialog(context),
              child: const Text('Abrir Atalhos'),
            ),
          ),
    ),
  );
}

void main() {
  group('AppShortcutsDialog', () {
    testWidgets('renderiza cabeçalho, abas, lista de atalhos e rodapé',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());

      await tester.tap(find.text('Abrir Atalhos'));
      await tester.pumpAndSettle();

      expect(find.text('Atalhos de Teclado'), findsOneWidget);
      expect(
        find.text('Comandos rápidos de produtividade para Desktop e Web'),
        findsOneWidget,
      );

      // Abas de categoria
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Navegação'), findsOneWidget);
      expect(find.text('Repertório & Áudio'), findsOneWidget);
      expect(find.text('Partituras'), findsOneWidget);
      expect(find.text('Cifras & Gestos'), findsOneWidget);

      // Itens da aba Todos
      expect(find.text('Ir para a Home e focar campo de busca'), findsOneWidget);
      expect(find.text('Avançar para o próximo louvor do repertório'), findsOneWidget);

      // Rodapé com dica rápida
      expect(
        find.text('Pressione ? em qualquer tela para abrir este painel a qualquer momento.'),
        findsOneWidget,
      );
      expect(find.text('Entendi'), findsOneWidget);

      // Fechar pelo botão 'Entendi'
      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      expect(find.byType(AppShortcutsDialog), findsNothing);
    });

    testWidgets('alterna entre as abas e filtra as ações corretamente',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());

      await tester.tap(find.text('Abrir Atalhos'));
      await tester.pumpAndSettle();

      // Navega para aba Partituras
      await tester.tap(find.text('Partituras'));
      await tester.pumpAndSettle();

      expect(find.text('Alternar modo de tela cheia'), findsOneWidget);
      expect(find.text('Avançar página ou rolar partitura'), findsOneWidget);
      expect(find.text('Ir para a primeira página'), findsOneWidget);

      // Navega para aba Cifras & Gestos
      await tester.tap(find.text('Cifras & Gestos'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ligar ou desligar rolagem automática (autoscroll)'),
        findsOneWidget,
      );
      expect(
        find.text('Transpor tom do louvor (+1 / -1 semitom)'),
        findsOneWidget,
      );
      expect(
        find.text('Próximo gesto ou gesto anterior na regência'),
        findsOneWidget,
      );

      // Fechar pelo botão 'X'
      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();
      expect(find.byType(AppShortcutsDialog), findsNothing);
    });
  });

  group('Atalho de Teclado (?) no AppShortcuts', () {
    testWidgets('pressionar ? abre a Central de Atalhos de Teclado',
        (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.home,
        routes: [
          GoRoute(
            path: RoutePaths.home,
            builder: (context, state) => const Scaffold(
              body: AppShortcuts(
                path: RoutePaths.home,
                child: Focus(
                  autofocus: true,
                  child: SizedBox.expand(),
                ),
              ),
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

      expect(find.byType(AppShortcutsDialog), findsNothing);

      // Dispara Shift + / (?)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(find.byType(AppShortcutsDialog), findsOneWidget);
      expect(find.text('Atalhos de Teclado'), findsOneWidget);

      // Tecla Escape fecha o diálogo
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(AppShortcutsDialog), findsNothing);
    });

    testWidgets('digitar ? dentro de um TextField não abre a central de atalhos',
        (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.home,
        routes: [
          GoRoute(
            path: RoutePaths.home,
            builder: (context, state) => const Scaffold(
              body: AppShortcuts(
                path: RoutePaths.home,
                child: TextField(
                  autofocus: true,
                ),
              ),
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

      expect(find.byType(AppShortcutsDialog), findsNothing);

      // Pressiona Shift + / (?) focado no campo de texto
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      // Diálogo NÃO deve ser aberto
      expect(find.byType(AppShortcutsDialog), findsNothing);
    });
  });
}
