import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/color_extensions.dart';

/// Widget reutilizável para estados vazios informativos e acionáveis no Coldigui.
///
/// Apresenta um ícone temático, título claro, mensagem descritiva de orientação
/// e botões opcionais de ação primária e secundária.
class ActionableEmptyState extends StatelessWidget {
  const ActionableEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.primaryActionIcon,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.secondaryActionIcon,
    this.compact = false,
    super.key,
  });

  /// Ícone principal do estado vazio.
  final IconData icon;

  /// Título explicativo (ex: "Nenhum louvor na lista ativa").
  final String title;

  /// Descrição e orientações pedagógicas para o usuário.
  final String description;

  /// Texto do botão de ação principal.
  final String? primaryActionLabel;

  /// Callback da ação principal.
  final VoidCallback? onPrimaryAction;

  /// Ícone opcional da ação principal.
  final IconData? primaryActionIcon;

  /// Texto do botão de ação secundária.
  final String? secondaryActionLabel;

  /// Callback da ação secundária.
  final VoidCallback? onSecondaryAction;

  /// Ícone opcional da ação secundária.
  final IconData? secondaryActionIcon;

  /// Se verdadeiro, reduz paddings para caber em espaços menores.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: compact ? 16 : 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge de ícone
              Container(
                width: compact ? 48 : 56,
                height: compact ? 48 : 56,
                decoration: BoxDecoration(
                  color: AppColors.card.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: compact ? 24 : 28,
                  color: AppColors.gold,
                ),
              ),
              SizedBox(height: compact ? 12 : 16),

              // Título
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.headline.copyWith(
                  color: AppColors.textLight,
                  fontSize: compact ? 16 : 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Descrição
              Text(
                description,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.textLight.withValues(alpha: 0.75),
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),

              // Botões de ação
              if (primaryActionLabel != null && onPrimaryAction != null) ...[
                SizedBox(height: compact ? 16 : 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.card,
                    foregroundColor: AppColors.title,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.gold, width: 1),
                    ),
                  ),
                  onPressed: onPrimaryAction,
                  icon: primaryActionIcon != null
                      ? Icon(primaryActionIcon, size: 18)
                      : const SizedBox.shrink(),
                  label: Text(
                    primaryActionLabel!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],

              if (secondaryActionLabel != null && onSecondaryAction != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.placeholder,
                  ),
                  onPressed: onSecondaryAction,
                  icon: secondaryActionIcon != null
                      ? Icon(secondaryActionIcon, size: 16)
                      : const SizedBox.shrink(),
                  label: Text(
                    secondaryActionLabel!,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
