import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../routing/route_paths.dart';
import '../steps/home_tutorial_steps.dart';

/// Controlador que orquestra a execução dos tutoriais no [SpotlightGuidePortal].
class TutorialController {
  final SpotlightGuidePortalController portalController =
      SpotlightGuidePortalController();

  /// Verifica se a rota especificada possui passos de tutorial registrados.
  bool hasTutorialFor(String? path) {
    if (path == null) return false;
    return switch (path) {
      RoutePaths.home => true,
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
      _ => const [],
    };
  }

  /// Inicia o tutorial da rota especificada.
  void startTutorialForRoute(BuildContext context, String? path) {
    final steps = stepsForRoute(context, path);
    if (steps.isEmpty) return;

    if (portalController.isShowing) {
      portalController.hide();
      return;
    }

    portalController.showSteps(steps);
  }

  /// Fecha o tutorial ativo se houver.
  void hide() {
    if (portalController.isShowing) {
      portalController.hide();
    }
  }
}

/// Provider do controller de tutoriais do aplicativo.
final tutorialControllerProvider = Provider<TutorialController>((ref) {
  final controller = TutorialController();
  ref.onDispose(() {
    controller.hide();
  });
  return controller;
});
