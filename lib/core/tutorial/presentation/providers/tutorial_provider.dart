import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../../features/catalog/presentation/providers/catalog_filters_provider.dart';
import '../../../../features/catalog/presentation/widgets/filters_panel.dart';
import '../../../routing/route_paths.dart';
import '../steps/audio_tutorial_steps.dart';
import '../steps/chords_tutorial_steps.dart';
import '../steps/gestures_tutorial_steps.dart';
import '../steps/home_tutorial_steps.dart';
import '../steps/library_tutorial_steps.dart';
import '../steps/offline_tutorial_steps.dart';
import '../steps/playlists_tutorial_steps.dart';
import '../steps/profile_tutorial_steps.dart';
import '../steps/reader_tutorial_steps.dart';

/// Controlador que orquestra a execução dos tutoriais no [SpotlightGuidePortal].
class TutorialController {
  TutorialController([this._ref]);

  final Ref? _ref;

  final SpotlightGuidePortalController portalController =
      SpotlightGuidePortalController();

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
