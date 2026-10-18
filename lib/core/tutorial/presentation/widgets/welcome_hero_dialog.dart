import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/color_extensions.dart';
import '../../../utils/app_haptics.dart';
import '../providers/tutorial_preferences_provider.dart';
import '../providers/tutorial_provider.dart';

/// Diálogo de boas-vindas exibido no primeiro acesso do usuário ao PLPCG.
///
/// Oferece uma introdução amigável e convida para o Tour Integrado de 1 minuto
/// ou permite explorar o aplicativo livremente.
class WelcomeHeroDialog extends StatelessWidget {
  const WelcomeHeroDialog({super.key});

  /// Exibe o diálogo de boas-vindas caso o contexto seja válido.
  static Future<void> show(BuildContext context) async {
    // Garante que a preferência seja gravada imediatamente antes de exibir,
    // assegurando que NUNCA apareça repetidamente em recarregamentos ou navegações.
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      container
          .read(tutorialPreferencesProvider.notifier)
          .markWelcomeHeroSeen();
    } catch (_) {}

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const WelcomeHeroDialog(),
    );

    if (result == true && context.mounted) {
      ProviderContainer? container;
      try {
        container = ProviderScope.containerOf(context, listen: false);
      } catch (_) {}
      container?.read(tutorialControllerProvider).startWelcomeTour(context);
    }
  }

  void _onStartTour(BuildContext context) {
    AppHaptics.lightImpact();
    ProviderContainer? container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } catch (_) {}

    container?.read(tutorialPreferencesProvider.notifier).markWelcomeHeroSeen();
    Navigator.of(context).pop(true);
  }

  void _onDismiss(BuildContext context) {
    AppHaptics.selectionClick();
    ProviderContainer? container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } catch (_) {}

    container?.read(tutorialPreferencesProvider.notifier).markWelcomeHeroSeen();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = l10n?.welcomeHeroTitle ?? 'Bem-vindo ao PLPCG!';
    final subtitle = l10n?.welcomeHeroSubtitle ??
        'O hinário digital e organizador de louvores para músicos, instrumentistas e ministérios.';
    final featureSearch = l10n?.welcomeHeroFeatureSearch ??
        'Busca rápida por número, título, ritmo e tags.';
    final featurePlaylists = l10n?.welcomeHeroFeaturePlaylists ??
        'Criação de listas e repertórios para o culto.';
    final featureReader = l10n?.welcomeHeroFeatureReader ??
        'Leitor de partituras e cifras com pedais Bluetooth.';
    final prompt = l10n?.welcomeHeroPrompt ??
        'Deseja fazer um tour rápido de 1 minuto para conhecer as principais funcionalidades?';
    final startTour = l10n?.welcomeHeroStartTour ?? 'Fazer Tour Rápido (1 min)';
    final dismiss = l10n?.welcomeHeroDismiss ?? 'Explorar por Conta Própria';

    return Dialog(
      key: const Key('welcome-hero-dialog'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      backgroundColor: AppColors.card,
      elevation: 8,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ícone e cabeçalho
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: AppColors.title,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.headline.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.title.withValues(alpha: 0.85),
                  height: 1.3,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),

              // Lista rápida de recursos
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    _FeatureItem(
                      icon: Icons.search_rounded,
                      text: featureSearch,
                    ),
                    const SizedBox(height: 6),
                    _FeatureItem(
                      icon: Icons.queue_music_rounded,
                      text: featurePlaylists,
                    ),
                    const SizedBox(height: 6),
                    _FeatureItem(
                      icon: Icons.menu_book_rounded,
                      text: featureReader,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Text(
                prompt,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.title.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 16),

              // Botões de ação
              FilledButton.icon(
                key: const Key('welcome-hero-start-tour'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.background,
                  foregroundColor: AppColors.textLight,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _onStartTour(context),
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: Text(
                  startTour,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('welcome-hero-dismiss'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.title,
                  side: BorderSide(
                    color: AppColors.title.withValues(alpha: 0.3),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _onDismiss(context),
                child: Text(
                  dismiss,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.gold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTypography.body.copyWith(
              fontSize: 12,
              color: AppColors.title,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}
