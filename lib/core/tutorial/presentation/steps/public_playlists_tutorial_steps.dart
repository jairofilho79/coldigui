import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';
import '../../../../l10n/app_localizations.dart';

import '../widgets/coldigui_tutorial_hint.dart';

/// Passos do tutorial da tela de Listas Públicas ([PublicPlaylistsScreen]).
List<SpotlightGuideStep> buildPublicPlaylistsTutorialSteps(
  BuildContext context,
) {
  final l10n = AppLocalizations.of(context);
  return [
    // 1. Banner de Autenticação / Nome de Usuário (quando necessário)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'public-playlists-auth-banner',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 14,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialPublicPlaylistsStep1Title ?? 'Seu Nome de Usuário',
          message:
              l10n?.tutorialPublicPlaylistsStep1Message ??
              'Faça login com sua conta Google e crie seu **@usuário** para compartilhar suas próprias listas públicas com a igreja.',
        ),
      ),
    ),

    // 2. Barra de Busca de Usuários
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'public-playlists-search-bar',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialPublicPlaylistsStep2Title ?? 'Buscar Irmãos e Equipes',
          message:
              l10n?.tutorialPublicPlaylistsStep2Message ??
              'Digite o **@usuário** de outros membros da equipe para localizar suas listas públicas e repertórios compartilhados.',
        ),
      ),
    ),

    // 3. Resultados e Importação
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'public-playlists-results',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.skip,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialPublicPlaylistsStep3Title ?? 'Listas e Importação',
          message:
              l10n?.tutorialPublicPlaylistsStep3Message ??
              'Nos resultados, visualize as listas publicadas e toque em **importar** para adicionar os louvores à sua lista ativa.',
        ),
      ),
    ),

    // 4. Ícone de ajuda (i)
    SpotlightGuideStep.item(
      SpotlightGuideStepItem(
        targetId: 'app-info-button',
        placement: SpotlightGuidePlacement.bottom,
        missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
        targetDecoration: coldiguiTargetDecoration(
          borderRadius: 20,
          padding: const EdgeInsets.all(4),
        ),
        hintBuilder: (context, guide) => ColdiguiTutorialHint(
          guide: guide,
          title: l10n?.tutorialPublicPlaylistsStep4Title ?? 'Ajuda & Tutoriais',
          message:
              l10n?.tutorialPublicPlaylistsStep4Message ??
              'Toque no **ícone (i)** a qualquer momento para rever este guia passo a passo!',
        ),
      ),
    ),
  ];
}
