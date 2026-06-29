import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/offline/presentation/utils/pdf_offline_error_ui.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('snackbar Baixar troca para aba offline a partir da biblioteca', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    late GoRouter router;

    router = GoRouter(
      initialLocation: RoutePaths.library,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => Scaffold(
            body: navigationShell,
            bottomNavigationBar: Text('branch-${navigationShell.currentIndex}'),
          ),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.library,
                  builder: (_, __) =>
                      const Scaffold(body: Text('Library Screen')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.offline,
                  builder: (_, __) =>
                      const Scaffold(body: Text('Offline Screen')),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Library Screen'), findsOneWidget);
    expect(router.state.uri.path, RoutePaths.library);
    expect(find.text('branch-0'), findsOneWidget);

    final libraryContext = tester.element(find.text('Library Screen'));
    showPdfOfflineUnavailableSnackbar(libraryContext);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.ensureVisible(find.text('Baixar'));
    await tester.tap(find.text('Baixar'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, RoutePaths.offline);
    expect(find.text('Offline Screen'), findsOneWidget);
    expect(find.text('branch-1'), findsOneWidget);
  });
}
