import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import 'tutorial_preferences_provider.dart';
import '../../../../features/catalog/presentation/providers/catalog_filters_provider.dart';
import '../../../../features/catalog/presentation/widgets/filters_panel.dart';
import '../../../routing/route_paths.dart';
import '../../../utils/app_haptics.dart';
import '../steps/about_tutorial_steps.dart';
import '../steps/app_shortcuts_tutorial_steps.dart';
import '../steps/audio_tutorial_steps.dart';
import '../steps/carousel_selection_tutorial_steps.dart';
import '../steps/chords_tutorial_steps.dart';
import '../steps/collaboration_dialogs_tutorial_steps.dart';
import '../steps/contribution_detail_tutorial_steps.dart';
import '../steps/contribute_tutorial_steps.dart';
import '../steps/extracted_material_editor_tutorial_steps.dart';
import '../steps/favorite_material_kinds_tutorial_steps.dart';
import '../steps/filters_tutorial_steps.dart';
import '../steps/gesture_focus_tutorial_steps.dart';
import '../steps/gestures_tutorial_steps.dart';
import '../steps/home_tutorial_steps.dart';
import '../steps/library_tutorial_steps.dart';
import '../steps/live_room_tutorial_steps.dart';
import '../steps/lyrics_tutorial_steps.dart';
import '../steps/material_sheet_tutorial_steps.dart';
import '../steps/my_contributions_tutorial_steps.dart';
import '../steps/offline_tutorial_steps.dart';
import '../steps/playlists_tutorial_steps.dart';
import '../steps/praise_tutorial_steps.dart';
import '../steps/profile_tutorial_steps.dart';
import '../steps/public_playlists_tutorial_steps.dart';
import '../steps/reader_tutorial_steps.dart';
import '../steps/welcome_tour_tutorial_steps.dart';
import '../widgets/welcome_hero_dialog.dart';

/// Controlador que orquestra a execução dos tutoriais no [SpotlightGuidePortal].
class TutorialController {
  TutorialController([this._ref]);

  final Ref? _ref;

  final List<SpotlightGuidePortalController> _portalControllers = [
    SpotlightGuidePortalController(),
  ];

  /// Controller ativo do portal de tutorial.
  SpotlightGuidePortalController get portalController =>
      _portalControllers.last;

  /// Registra um controller de portal específico (ex: telas sobrepostas fora do Shell).
  void pushPortalController(SpotlightGuidePortalController controller) {
    _portalControllers.add(controller);
  }

  /// Remove o controller de portal registrado.
  void popPortalController(SpotlightGuidePortalController controller) {
    _portalControllers.remove(controller);
  }

  /// Verifica se a rota especificada possui passos de tutorial registrados.
  bool hasTutorialFor(String? path) {
    if (path == null) return false;
    return switch (path) {
      RoutePaths.home => true,
      RoutePaths.playlists => true,
      RoutePaths.profile => true,
      RoutePaths.reader => true,
      RoutePaths.library => true,
      RoutePaths.chords => true,
      RoutePaths.gestos => true,
      RoutePaths.audio => true,
      RoutePaths.offline => true,
      RoutePaths.lyrics => true,
      RoutePaths.praise => true,
      RoutePaths.about => true,
      RoutePaths.favoriteMaterialKinds => true,
      RoutePaths.myContributions => true,
      RoutePaths.publicPlaylists => true,
      RoutePaths.contribute => true,
      RoutePaths.liveRoom => true,
      RoutePaths.contributionDetail => true,
      'modal:material-sheet' => true,
      'modal:carousel-selection' => true,
      'modal:filters' => true,
      'modal:extracted-editor' => true,
      'modal:gesture-focus' => true,
      'modal:playlist-share' => true,
      'modal:publish-playlist' => true,
      'modal:join-live-room' => true,
      'modal:app-shortcuts' => true,
      'tour:welcome' => true,
      'welcome-tour' => true,
      final p when p.startsWith('/ao-vivo/') => true,
      final p when p.startsWith('/louvor/') => true,
      final p when p.startsWith('/contribuicoes/') => true,
      _ => false,
    };
  }

  /// Retorna a lista de passos para a rota especificada.
  List<SpotlightGuideStep> stepsForRoute(
    BuildContext context,
    String? path,
  ) {
    if (path == null) return const [];
    return switch (path) {
      RoutePaths.home => buildHomeTutorialSteps(context),
      RoutePaths.playlists => buildPlaylistsTutorialSteps(context),
      RoutePaths.profile => buildProfileTutorialSteps(context),
      RoutePaths.reader => buildReaderTutorialSteps(context),
      RoutePaths.library => buildLibraryTutorialSteps(context),
      RoutePaths.chords => buildChordsTutorialSteps(context),
      RoutePaths.gestos => buildGesturesTutorialSteps(context),
      RoutePaths.audio => buildAudioTutorialSteps(context),
      RoutePaths.offline => buildOfflineTutorialSteps(context),
      RoutePaths.lyrics => buildLyricsTutorialSteps(context),
      RoutePaths.praise => buildPraiseTutorialSteps(context),
      RoutePaths.about => buildAboutTutorialSteps(context),
      RoutePaths.favoriteMaterialKinds =>
        buildFavoriteMaterialKindsTutorialSteps(context),
      RoutePaths.myContributions =>
        buildMyContributionsTutorialSteps(context),
      RoutePaths.publicPlaylists =>
        buildPublicPlaylistsTutorialSteps(context),
      RoutePaths.contribute =>
        _ref?.read(extractedEditorActiveProvider) == true
            ? buildExtractedMaterialEditorTutorialSteps(context)
            : buildContributeTutorialSteps(context),
      RoutePaths.liveRoom =>
        buildLiveRoomTutorialSteps(context),
      RoutePaths.contributionDetail =>
        buildContributionDetailTutorialSteps(context),
      'modal:material-sheet' =>
        buildMaterialSheetTutorialSteps(context),
      'modal:carousel-selection' =>
        buildCarouselSelectionTutorialSteps(context),
      'modal:filters' =>
        buildFiltersTutorialSteps(context),
      'modal:extracted-editor' =>
        buildExtractedMaterialEditorTutorialSteps(context),
      'modal:gesture-focus' =>
        buildGestureFocusTutorialSteps(context),
      'modal:playlist-share' =>
        buildPlaylistShareTutorialSteps(context),
      'modal:publish-playlist' =>
        buildPublishPlaylistTutorialSteps(context),
      'modal:join-live-room' =>
        buildJoinLiveRoomTutorialSteps(context),
      'modal:app-shortcuts' =>
        buildAppShortcutsTutorialSteps(context),
      'tour:welcome' || 'welcome-tour' =>
        buildWelcomeTourTutorialSteps(context),
      final p when p.startsWith('/ao-vivo/') =>
        buildLiveRoomTutorialSteps(context),
      final p when p.startsWith('/louvor/') =>
        buildPraiseTutorialSteps(context),
      final p when p.startsWith('/contribuicoes/') =>
        buildContributionDetailTutorialSteps(context),
      _ => const [],
    };
  }

  /// Inicia o tutorial da rota especificada.
  void startTutorialForRoute(BuildContext context, String? path) {
    final steps = stepsForRoute(context, path);
    if (steps.isEmpty) return;

    if (portalController.isShowing) {
      hide();
      return;
    }

    portalController.showSteps(steps);
  }

  /// Executa uma lista arbitrária de passos de tutorial no portal ativo.
  void showSteps(List<SpotlightGuideStep> steps) {
    if (steps.isEmpty) return;
    if (portalController.isShowing) {
      hide();
      return;
    }
    unawaited(AppHaptics.lightImpact());
    portalController.showSteps(steps);
  }

  /// Inicia o tutorial do seletor de materiais ([MaterialSheet]).
  void startMaterialSheetTutorial(BuildContext context) {
    showSteps(buildMaterialSheetTutorialSteps(context));
  }

  /// Inicia o tutorial do gerenciador da lista ativa ([CarouselSelectionSheet]).
  void startCarouselSelectionTutorial(BuildContext context) {
    showSteps(buildCarouselSelectionTutorialSteps(context));
  }

  /// Inicia o tutorial do painel de filtros ([FiltersPanel]).
  void startFiltersTutorial(
    BuildContext context, [
    CatalogFilterScope scope = CatalogFilterScope.home,
  ]) {
    _ref?.read(filtersPanelExpandedOverrideProvider(scope).notifier).set(true);
    showSteps(buildFiltersTutorialSteps(context));
  }

  /// Inicia o tutorial do editor de materiais extraídos ([ExtractedMaterialEditorScaffold]).
  void startExtractedMaterialEditorTutorial(BuildContext context) {
    showSteps(buildExtractedMaterialEditorTutorialSteps(context));
  }

  /// Inicia o tutorial do modo foco de gestos ([GestureFocusView]).
  void startGestureFocusTutorial(BuildContext context) {
    showSteps(buildGestureFocusTutorialSteps(context));
  }

  /// Inicia o tutorial do diálogo de compartilhamento ([PlaylistShareSheet]).
  void startPlaylistShareTutorial(BuildContext context) {
    showSteps(buildPlaylistShareTutorialSteps(context));
  }

  /// Inicia o tutorial do diálogo de publicação na comunidade ([PublishPlaylistDialog]).
  void startPublishPlaylistTutorial(BuildContext context) {
    showSteps(buildPublishPlaylistTutorialSteps(context));
  }

  /// Inicia o tutorial do diálogo de entrada em sala ao vivo ([JoinLiveRoomDialog]).
  void startJoinLiveRoomTutorial(BuildContext context) {
    showSteps(buildJoinLiveRoomTutorialSteps(context));
  }

  /// Inicia o tutorial da Central de Atalhos de Teclado ([AppShortcutsDialog]).
  void startAppShortcutsTutorial(BuildContext context) {
    showSteps(buildAppShortcutsTutorialSteps(context));
  }

  /// Inicia o tour integrado de boas-vindas do Coldigui ([buildWelcomeTourTutorialSteps]).
  void startWelcomeTour(BuildContext context) {
    _ref?.read(tutorialPreferencesProvider.notifier).markSeen('welcome-tour');
    showSteps(buildWelcomeTourTutorialSteps(context));
  }

  /// Inicia o tutorial da rota especificada de forma suave caso as preferências
  /// do usuário permitam (primeiro acesso e sem opção "Não mostrar novamente").
  ///
  /// Requer um [SpotlightGuidePortal] ancestral na árvore, garantindo isolamento gracioso
  /// em testes unitários que montam telas sem o shell.
  void maybeAutoStartTutorial(
    BuildContext context,
    String routePath, {
    Duration delay = const Duration(milliseconds: 500),
    bool forceAllowedRoute = false,
  }) {
    final autoTriggerEnabled =
        _ref?.read(tutorialAutoTriggerEnabledProvider) ?? true;
    if (!autoTriggerEnabled) return;

    final prefsState = _ref?.read(tutorialPreferencesProvider);
    if (prefsState != null &&
        !prefsState.shouldAutoTrigger(
          routePath,
          forceAllowedRoute: forceAllowedRoute,
        )) {
      return;
    }

    if (!hasTutorialFor(routePath)) return;

    final portal = context.findAncestorWidgetOfExactType<SpotlightGuidePortal>();
    if (portal == null) return;

    // Registra como visto para não enfileirar duplicatas no mesmo ciclo
    _ref?.read(tutorialPreferencesProvider.notifier).markSeen(routePath);

    Future.delayed(delay, () {
      if (!context.mounted) return;
      if (portalController.isShowing) return;
      startTutorialForRoute(context, routePath);
    });
  }

  /// Inicia o diálogo de boas-vindas no primeiríssimo acesso ou, se já visto,
  /// o tutorial automático suave da página inicial.
  void maybeAutoStartWelcomeFlow(
    BuildContext context, {
    Duration delay = const Duration(milliseconds: 500),
  }) {
    final autoTriggerEnabled =
        _ref?.read(tutorialAutoTriggerEnabledProvider) ?? true;
    if (!autoTriggerEnabled) return;

    final prefsState = _ref?.read(tutorialPreferencesProvider);
    if (prefsState?.dismissAll == true) return;

    final portal =
        context.findAncestorWidgetOfExactType<SpotlightGuidePortal>();
    if (portal == null) return;

    if (prefsState != null && !prefsState.hasSeenWelcomeHero) {
      _ref?.read(tutorialPreferencesProvider.notifier).markWelcomeHeroSeen();
      Future.delayed(delay, () {
        if (!context.mounted) return;
        if (portalController.isShowing) return;
        WelcomeHeroDialog.show(context);
      });
      return;
    }

    maybeAutoStartTutorial(context, RoutePaths.home, delay: delay);
  }

  /// Restaura qualquer estado alterado durante a apresentação do tutorial.
  void resetTutorialState() {
    _ref
        ?.read(
          filtersPanelExpandedOverrideProvider(CatalogFilterScope.home)
              .notifier,
        )
        .set(null);
    _ref
        ?.read(
          filtersPanelExpandedOverrideProvider(CatalogFilterScope.library)
              .notifier,
        )
        .set(null);
    _ref
        ?.read(catalogFiltersProviderFor(CatalogFilterScope.home).notifier)
        .restoreTutorialFilters();
    _ref
        ?.read(catalogFiltersProviderFor(CatalogFilterScope.library).notifier)
        .restoreTutorialFilters();
  }

  /// Fecha o tutorial ativo se houver e restaura o estado.
  void hide() {
    resetTutorialState();
    if (portalController.isShowing) {
      portalController.hide();
    }
  }
}

/// Provider do controller de tutoriais do aplicativo.
final tutorialControllerProvider = Provider<TutorialController>((ref) {
  final controller = TutorialController(ref);
  ref.onDispose(() {
    if (controller.portalController.isShowing) {
      controller.portalController.hide();
    }
  });
  return controller;
});

/// Notifier que controla se o editor de materiais extraídos está ativo na tela de contribuição.
class ExtractedEditorActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Provider que sinaliza se o editor de materiais extraídos está ativo na tela de contribuição.
final extractedEditorActiveProvider =
    NotifierProvider<ExtractedEditorActiveNotifier, bool>(
  ExtractedEditorActiveNotifier.new,
);
