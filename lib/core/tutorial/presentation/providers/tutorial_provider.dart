import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../../features/catalog/presentation/providers/catalog_filters_provider.dart';
import '../../../../features/catalog/presentation/widgets/filters_panel.dart';
import '../../../routing/route_paths.dart';
import '../steps/about_tutorial_steps.dart';
import '../steps/audio_tutorial_steps.dart';
import '../steps/carousel_selection_tutorial_steps.dart';
import '../steps/chords_tutorial_steps.dart';
import '../steps/contribution_detail_tutorial_steps.dart';
import '../steps/contribute_tutorial_steps.dart';
import '../steps/favorite_material_kinds_tutorial_steps.dart';
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
        buildContributeTutorialSteps(context),
      RoutePaths.liveRoom =>
        buildLiveRoomTutorialSteps(context),
      RoutePaths.contributionDetail =>
        buildContributionDetailTutorialSteps(context),
      'modal:material-sheet' =>
        buildMaterialSheetTutorialSteps(context),
      'modal:carousel-selection' =>
        buildCarouselSelectionTutorialSteps(context),
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

  /// Restaura qualquer estado alterado durante a apresentação do tutorial.
  void resetTutorialState() {
    _ref
        ?.read(
          filtersPanelExpandedOverrideProvider(CatalogFilterScope.home)
              .notifier,
        )
        .set(null);
    _ref
        ?.read(catalogFiltersProviderFor(CatalogFilterScope.home).notifier)
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
