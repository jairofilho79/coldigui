import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/contribution_summary.dart';

/// Texto do estado (spec §6.4 — tabela status → texto).
String contributionStatusLabel(AppLocalizations l10n, ContributionStatus s) =>
    switch (s) {
      ContributionStatus.recebida => l10n.contributionStatusRecebida,
      ContributionStatus.pendente => l10n.contributionStatusPendente,
      ContributionStatus.emAnalise => l10n.contributionStatusEmAnalise,
      ContributionStatus.aceita => l10n.contributionStatusAceita,
      ContributionStatus.recusada => l10n.contributionStatusRecusada,
      ContributionStatus.aplicada => l10n.contributionStatusAplicada,
      ContributionStatus.bloqueada => l10n.contributionStatusBloqueada,
    };

/// Cor do estado: verde quando o time aceitou/aplicou, vermelho quando
/// recusou/bloqueou, dourado em análise, cor neutra no resto (recebida/pendente).
Color contributionStatusColor(ContributionStatus s) => switch (s) {
  ContributionStatus.aceita ||
  ContributionStatus.aplicada => AppColors.offlineReady,
  ContributionStatus.recusada ||
  ContributionStatus.bloqueada => AppColors.offlineMissing,
  ContributionStatus.emAnalise => AppColors.gold,
  _ => AppColors.placeholder,
};

/// Pílula colorida com o texto do estado (spec §6.4) — usada no `ListTile`
/// da lista e no cabeçalho do detalhe.
class ContributionStatusChip extends StatelessWidget {
  const ContributionStatusChip({required this.status, super.key});

  final ContributionStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = contributionStatusColor(status);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 130),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          contributionStatusLabel(l10n, status),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.label.copyWith(color: color),
        ),
      ),
    );
  }
}
