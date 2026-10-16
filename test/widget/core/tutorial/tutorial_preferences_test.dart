import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/tutorial/presentation/providers/tutorial_preferences_provider.dart';
import 'package:coldigui/core/tutorial/presentation/providers/tutorial_provider.dart';
import 'package:coldigui/core/tutorial/presentation/widgets/coldigui_tutorial_hint.dart';
import 'package:coldigui/features/app_shell/presentation/pages/profile_screen.dart';
import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

class _LoggedOutAuth extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TutorialPreferencesState', () {
    test('estado inicial padrão permite auto-trigger apenas nas rotas autorizadas', () {
      const state = TutorialPreferencesState();
      expect(state.dismissAll, isFalse);
      expect(state.seenTutorials, isEmpty);
      expect(state.hasSeen(RoutePaths.home), isFalse);
      expect(state.shouldAutoTrigger(RoutePaths.home), isTrue);
      expect(state.shouldAutoTrigger(RoutePaths.reader), isTrue);
      // Rota não incluída em kDefaultAutoTriggerRoutes não dispara por padrão
      expect(state.shouldAutoTrigger(RoutePaths.playlists), isFalse);
      // Salvo se forçado
      expect(state.shouldAutoTrigger(RoutePaths.playlists, forceAllowedRoute: true), isTrue);
    });

    test('dismissAll desativa qualquer auto-trigger', () {
      const state = TutorialPreferencesState(dismissAll: true);
      expect(state.shouldAutoTrigger(RoutePaths.home), isFalse);
      expect(state.shouldAutoTrigger(RoutePaths.reader), isFalse);
      expect(state.shouldAutoTrigger(RoutePaths.home, forceAllowedRoute: true), isFalse);
    });

    test('rota já visualizada não deve disparar novamente', () {
      const state = TutorialPreferencesState(
        seenTutorials: {RoutePaths.home},
      );
      expect(state.hasSeen(RoutePaths.home), isTrue);
      expect(state.shouldAutoTrigger(RoutePaths.home), isFalse);
      expect(state.shouldAutoTrigger(RoutePaths.reader), isTrue);
    });

    test('copyWith preserva e atualiza campos', () {
      const initial = TutorialPreferencesState();
      final updated = initial.copyWith(
        dismissAll: true,
        seenTutorials: {RoutePaths.home},
      );
      expect(updated.dismissAll, isTrue);
      expect(updated.seenTutorials, {RoutePaths.home});
      expect(updated, isNot(equals(initial)));
    });
  });

  group('TutorialPreferencesNotifier & Persistência Local', () {
    test('carrega preferências salvas no boot', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.tutorialDismissAll: true,
        '${StorageKeys.tutorialSeenPrefix}${RoutePaths.home}': true,
        '${StorageKeys.tutorialSeenPrefix}${RoutePaths.reader}': true,
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final state = container.read(tutorialPreferencesProvider);
      expect(state.dismissAll, isTrue);
      expect(state.hasSeen(RoutePaths.home), isTrue);
      expect(state.hasSeen(RoutePaths.reader), isTrue);
      expect(state.hasSeen(RoutePaths.playlists), isFalse);
    });

    test('markSeen atualiza estado e persiste chave individual', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(tutorialPreferencesProvider.notifier);
      await notifier.markSeen(RoutePaths.home);

      final state = container.read(tutorialPreferencesProvider);
      expect(state.hasSeen(RoutePaths.home), isTrue);
      expect(
        prefs.getBool('${StorageKeys.tutorialSeenPrefix}${RoutePaths.home}'),
        isTrue,
      );
    });

    test('setDismissAll atualiza flag global e persiste chave', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(tutorialPreferencesProvider.notifier);
      await notifier.setDismissAll(true);

      final state = container.read(tutorialPreferencesProvider);
      expect(state.dismissAll, isTrue);
      expect(prefs.getBool(StorageKeys.tutorialDismissAll), isTrue);
    });

    test('resetAll limpa chaves de preferências e reinicia estado', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.tutorialDismissAll: true,
        '${StorageKeys.tutorialSeenPrefix}${RoutePaths.home}': true,
        '${StorageKeys.tutorialSeenPrefix}${RoutePaths.reader}': true,
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(tutorialPreferencesProvider.notifier);
      await notifier.resetAll();

      final state = container.read(tutorialPreferencesProvider);
      expect(state.dismissAll, isFalse);
      expect(state.seenTutorials, isEmpty);
      expect(prefs.getBool(StorageKeys.tutorialDismissAll), isNull);
      expect(
        prefs.getBool('${StorageKeys.tutorialSeenPrefix}${RoutePaths.home}'),
        isNull,
      );
    });
  });

  group('ColdiguiTutorialHint - Ações de Fechamento e Não Mostrar Novamente', () {
    testWidgets('botão Não mostrar novamente define dismissAll e fecha guia', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SpotlightGuidePortal(
                steps: [
                  SpotlightGuideStep.item(
                    SpotlightGuideStepItem(
                      targetId: 'hint-test-target',
                      hintBuilder: (context, guide) => ColdiguiTutorialHint(
                        guide: guide,
                        title: 'Dica com Dismiss',
                        message: 'Mensagem de teste.',
                      ),
                    ),
                  ),
                ],
                child: SpotlightGuideTarget(
                  id: 'hint-test-target',
                  child: const Text('Alvo'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dica com Dismiss'), findsOneWidget);
      expect(find.byKey(const ValueKey('tutorial-hint-dismiss-forever')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tutorial-hint-dismiss-forever')));
      await tester.pumpAndSettle();

      // O balão fechou
      expect(find.text('Dica com Dismiss'), findsNothing);

      // O estado foi persistido como dismissAll = true
      final state = container.read(tutorialPreferencesProvider);
      expect(state.dismissAll, isTrue);
      expect(prefs.getBool(StorageKeys.tutorialDismissAll), isTrue);
    });

    testWidgets('botão Pular fecha o guia sem marcar dismissAll global', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SpotlightGuidePortal(
                steps: [
                  SpotlightGuideStep.item(
                    SpotlightGuideStepItem(
                      targetId: 'hint-test-target-2',
                      hintBuilder: (context, guide) => ColdiguiTutorialHint(
                        guide: guide,
                        title: 'Dica para Pular',
                        message: 'Mensagem de teste.',
                      ),
                    ),
                  ),
                ],
                child: SpotlightGuideTarget(
                  id: 'hint-test-target-2',
                  child: const Text('Alvo'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dica para Pular'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tutorial-hint-skip')));
      await tester.pumpAndSettle();

      expect(find.text('Dica para Pular'), findsNothing);
      final state = container.read(tutorialPreferencesProvider);
      expect(state.dismissAll, isFalse);
    });
  });

  group('TutorialController.maybeAutoStartTutorial', () {
    testWidgets('dispara tutorial e marca como visto quando permitido e dentro do portal', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final controller = container.read(tutorialControllerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SpotlightGuidePortal(
              controller: controller.portalController,
              autoStart: false,
              missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
              child: Scaffold(
                body: Builder(
                  builder: (context) {
                    return Column(
                      children: [
                        SpotlightGuideTarget(
                          id: 'home-search-bar',
                          child: const Text('Barra de Pesquisa'),
                        ),
                        SpotlightGuideTarget(
                          id: 'home-filter-chip-sample',
                          child: const Text('Filtro'),
                        ),
                        SpotlightGuideTarget(
                          id: 'home-louvor-card-sample',
                          child: const Text('Card'),
                        ),
                        SpotlightGuideTarget(
                          id: 'home-bottom-nav',
                          child: const Text('Nav'),
                        ),
                        SpotlightGuideTarget(
                          id: 'app-info-button',
                          child: const Text('Info'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffoldContext = tester.element(find.byType(Scaffold));

      // Chama auto start
      controller.maybeAutoStartTutorial(
        scaffoldContext,
        RoutePaths.home,
        delay: const Duration(milliseconds: 50),
      );

      // Avança o delay de 50ms do auto-start + 150ms do onReveal do primeiro passo
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Tutorial da Home deve ter sido iniciado
      expect(find.text('Pesquisa Inteligente'), findsOneWidget);

      // E a rota já foi gravada como vista
      final state = container.read(tutorialPreferencesProvider);
      expect(state.hasSeen(RoutePaths.home), isTrue);
    });

    testWidgets('não dispara se dismissAll estiver ativo', (tester) async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.tutorialDismissAll: true,
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final controller = container.read(tutorialControllerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SpotlightGuidePortal(
              controller: controller.portalController,
              child: const Scaffold(body: Text('Corpo')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffoldContext = tester.element(find.byType(Scaffold));
      controller.maybeAutoStartTutorial(
        scaffoldContext,
        RoutePaths.home,
        delay: const Duration(milliseconds: 50),
      );

      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();

      expect(find.text('Pesquisa Inteligente'), findsNothing);
    });

    testWidgets('não dispara se não houver SpotlightGuidePortal na árvore', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final controller = container.read(tutorialControllerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: Text('Sem portal')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffoldContext = tester.element(find.byType(Scaffold));
      controller.maybeAutoStartTutorial(
        scaffoldContext,
        RoutePaths.home,
        delay: const Duration(milliseconds: 50),
      );

      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();

      // Não deve ter marcado como visto nem aberto nada
      final state = container.read(tutorialPreferencesProvider);
      expect(state.hasSeen(RoutePaths.home), isFalse);
    });
  });

  group('ProfileScreen - Redefinir Tutoriais', () {
    testWidgets('renderiza tile de redefinir tutoriais e diálogo de confirmação', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.tutorialDismissAll: true,
        '${StorageKeys.tutorialSeenPrefix}${RoutePaths.home}': true,
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith(_LoggedOutAuth.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            home: const Scaffold(body: ProfileScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Encontra o tile de Redefinir Tutoriais
      final resetTile = find.byKey(const ValueKey('profile-reset-tutorials-tile'));
      expect(resetTile, findsOneWidget);
      expect(find.text('Redefinir Tutoriais'), findsOneWidget);

      // Abre diálogo
      await tester.tap(resetTile);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text(
          'Deseja redefinir todos os tutoriais? Os guias de introdução voltarão a ser exibidos automaticamente ao acessar as telas do aplicativo.',
        ),
        findsOneWidget,
      );

      // Testa Cancelar
      await tester.tap(find.byKey(const ValueKey('reset-tutorials-cancel-button')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(container.read(tutorialPreferencesProvider).dismissAll, isTrue);

      // Abre novamente e confirma
      await tester.tap(resetTile);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('reset-tutorials-confirm-button')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Tutoriais redefinidos com sucesso!'), findsOneWidget);

      // Preferências foram limpas
      final state = container.read(tutorialPreferencesProvider);
      expect(state.dismissAll, isFalse);
      expect(state.hasSeen(RoutePaths.home), isFalse);
    });
  });
}
