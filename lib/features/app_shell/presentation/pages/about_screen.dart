import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotlight_guide/spotlight_guide.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/routing/shell_navigation.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/tutorial/presentation/providers/tutorial_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/about_info_card.dart';
import '../widgets/app_shortcuts_dialog.dart';

/// UC-14 — Tela Sobre ([RoutePaths.about]): Quem somos e Objetivo da aplicação.
///
/// Layout scrollável centralizado com `maxWidth: 896` (paridade
/// [LibraryScreen] / [HomeScreen]). Dois [AboutInfoCard]: "Quem somos"
/// (1 parágrafo) e "Objetivo" (2 parágrafos).
///
/// Consumidores: [appRouterProvider] → branch Perfil ([RoutePaths.about]).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const double _maxContentWidth = 896;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            SpotlightGuideTarget(
              id: 'about-who-we-are',
              child: AboutInfoCard(
                title: l10n.aboutWhoWeAreTitle,
                paragraphs: [l10n.aboutWhoWeAreBody],
              ),
            ),
            const SizedBox(height: 16),
            SpotlightGuideTarget(
              id: 'about-mission',
              child: AboutInfoCard(
                title: l10n.aboutObjectiveTitle,
                paragraphs: [l10n.aboutObjectiveParagraph1, l10n.aboutObjectiveParagraph2],
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.shortcutsTitle,
                                style: const TextStyle(
                                  fontFamily: AppTypography.garamondFamily,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  letterSpacing: 0.3,
                                  color: AppColors.title,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.shortcutsAboutDescription,
                                style: const TextStyle(
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.welcomeTourAboutTitle,
                                style: const TextStyle(
                                  fontFamily: AppTypography.garamondFamily,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  letterSpacing: 0.3,
                                  color: AppColors.title,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.welcomeTourAboutDescription,
                                style: const TextStyle(
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
              id: 'about-privacy-policy-card',
              child: Material(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: const ValueKey('about-privacy-policy-button'),
                  onTap: () async {
                    const baseUrl = String.fromEnvironment(
                      'PLPCG_API_BASE_URL',
                      defaultValue: 'https://plpcg.com',
                    );
                    final uri = Uri.parse('$baseUrl/privacy');
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                            Icons.privacy_tip_outlined,
                            color: AppColors.goldLight,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.privacyPolicyTitle,
                                style: const TextStyle(
                                  fontFamily: AppTypography.garamondFamily,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  letterSpacing: 0.3,
                                  color: AppColors.title,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.privacyPolicyAboutDescription,
                                style: const TextStyle(
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
                          Icons.open_in_new,
                          color: AppColors.title,
                          size: 20,
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

