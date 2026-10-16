import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/routing/shell_navigation.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/tutorial/presentation/providers/tutorial_provider.dart';
import '../widgets/about_info_card.dart';
import '../widgets/app_shortcuts_dialog.dart';

/// UC-14 — Tela Sobre ([RoutePaths.about]): Quem somos e Objetivo da aplicação.
///
/// Layout scrollável centralizado com `maxWidth: 896` (paridade
/// [LibraryScreen] / [HomeScreen]). Dois [AboutInfoCard]: "Quem somos"
/// (1 parágrafo) e "Objetivo" (2 parágrafos).
///
/// Conteúdo institucional fixo em PT — sem [AppLocalizations] nesta entrega.
///
/// Consumidores: [appRouterProvider] → branch Perfil ([RoutePaths.about]).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const double _maxContentWidth = 896;

  static const _quemSomosBody =
      'A Paz do Senhor Jesus. Somos irmãos da Igreja Cristã Maranata '
      'da Região do Triângulo Mineiro e servimos no Maanaim de Uberlândia-MG. '
      'Esta aplicação não é oficial da ICM, mas o objetivo é ajudar a todos '
      'que estão no louvor ajudando na Obra. Seguindo as orientações da Igreja. '
      'De forma 100% gratuita.';

  static const _objetivoParagraph1 =
      'O objetivo da aplicação - chamada Pesquisador de Louvores em Partitura, '
      'Cifra em Geral - é ajudar aos irmãos da equipe de louvor '
      'com os materiais mais básicos pro louvor. Que seja fácil de pesquisar, '
      'consumir e que funcione offline, pois muita igrejas não tem internet ou '
      'é muito difícil o acesso em ESFs.';

  static const _objetivoParagraph2 =
      'Portanto, estejamos em oração por todos os irmãos que estão envolvidos '
      'nesse projeto. Quer seja diretamente no desenvolvimento da aplicação, '
      'quer seja na produção dos materiais, no uso/teste da aplicação e afins.';

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const SpotlightGuideTarget(
              id: 'about-who-we-are',
              child: AboutInfoCard(
                title: 'Quem somos',
                paragraphs: [_quemSomosBody],
              ),
            ),
            const SizedBox(height: 16),
            const SpotlightGuideTarget(
              id: 'about-mission',
              child: AboutInfoCard(
                title: 'Objetivo',
                paragraphs: [_objetivoParagraph1, _objetivoParagraph2],
              ),
            ),
            const SizedBox(height: 16),
            SpotlightGuideTarget(
              id: 'about-shortcuts-card',
              child: Material(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => showAppShortcutsDialog(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.background, width: 1.5),
                      boxShadow: AppColors.shadowMd,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.gold, width: 1),
                          ),
                          child: const Icon(
                            Icons.keyboard_outlined,
                            color: AppColors.goldLight,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Atalhos de Teclado',
                                style: TextStyle(
                                  fontFamily: AppTypography.garamondFamily,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  letterSpacing: 0.3,
                                  color: AppColors.title,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Consulte os comandos rápidos de alta produtividade para Desktop e Web.',
                                style: TextStyle(
                                  fontFamily: AppTypography.sansFamily,
                                  fontSize: 13,
                                  color: AppColors.textDark,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.title,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SpotlightGuideTarget(
              id: 'about-welcome-tour-card',
              child: Material(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: const ValueKey('about-welcome-tour-button'),
                  onTap: () {
                    goToShellDestination(context, RoutePaths.home);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      try {
                        final container = ProviderScope.containerOf(
                          context,
                          listen: false,
                        );
                        container
                            .read(tutorialControllerProvider)
                            .startWelcomeTour(context);
                      } catch (_) {}
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.background, width: 1.5),
                      boxShadow: AppColors.shadowMd,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: AppColors.gold, width: 1),
                          ),
                          child: const Icon(
                            Icons.explore_outlined,
                            color: AppColors.goldLight,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tour de Boas-Vindas',
                                style: TextStyle(
                                  fontFamily: AppTypography.garamondFamily,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  letterSpacing: 0.3,
                                  color: AppColors.title,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Faça o tour guiado de 4 passos conhecendo o fluxo do acervo ao culto.',
                                style: TextStyle(
                                  fontFamily: AppTypography.sansFamily,
                                  fontSize: 13,
                                  color: AppColors.textDark,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.title,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

