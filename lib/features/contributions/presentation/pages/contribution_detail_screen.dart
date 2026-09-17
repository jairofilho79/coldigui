import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/utils/byte_format.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/contribution_kind.dart';
import '../../domain/entities/contribution_summary.dart';
import '../providers/my_contributions_provider.dart';
import '../widgets/contribution_status_chip.dart';

/// Detalhe de uma contribuição (spec §6.4): título, estado, corpo, campos
/// estruturados, anexos com estado do scan em linguagem humana, links e nota
/// da equipe — sub-página da branch Perfil, sem `Scaffold`/`AppBar` próprio.
class ContributionDetailScreen extends ConsumerWidget {
  const ContributionDetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(contributionDetailProvider(id));
    return async.when(
      data: (c) => _DetailBody(contribution: c),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.errorGeneric,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: AppColors.textLight),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(contributionDetailProvider(id)),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.contribution});

  final ContributionSummary contribution;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = contribution;
    final metadataLine = _metadataLine(l10n, c.fields);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                c.title,
                style: AppTypography.headline.copyWith(
                  color: AppColors.textLight,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ContributionStatusChip(status: c.status),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _kindLabel(l10n, c.kind),
          style: AppTypography.body.copyWith(
            color: AppColors.textLight.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          c.body,
          style: AppTypography.body.copyWith(color: AppColors.textLight),
        ),
        if (metadataLine != null) ...[
          const SizedBox(height: 16),
          Text(
            metadataLine,
            style: AppTypography.body.copyWith(color: AppColors.textLight),
          ),
        ],
        if (c.links.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final link in c.links)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SelectableText(
                link,
                style: AppTypography.body.copyWith(
                  color: AppColors.textLight,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
        if (c.files.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.contributionFilesTitle,
            style: AppTypography.headline.copyWith(color: AppColors.textLight),
          ),
          const SizedBox(height: 8),
          for (final file in c.files)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${file.originalName} · ${formatCompactBytes(file.size)} · '
                '${_scanLabel(l10n, file.scanStatus)}',
                style: AppTypography.body.copyWith(color: AppColors.textLight),
              ),
            ),
        ],
        if (c.decisionNote != null) ...[
          const SizedBox(height: 16),
          Text(
            l10n.contributionDecisionNote,
            style: AppTypography.headline.copyWith(color: AppColors.textLight),
          ),
          const SizedBox(height: 8),
          Text(
            c.decisionNote!,
            style: AppTypography.body.copyWith(color: AppColors.textLight),
          ),
        ],
      ],
    );
  }
}

String _kindLabel(AppLocalizations l10n, ContributionKind kind) =>
    switch (kind) {
      ContributionKind.bug => l10n.contributeKindBug,
      ContributionKind.wrongInfo => l10n.contributeKindWrongInfo,
      ContributionKind.content => l10n.contributeKindContent,
      ContributionKind.improvement => l10n.contributeKindImprovement,
      ContributionKind.other => l10n.contributeKindOther,
    };

/// `limpa` → ok; `suspeita`/`infectada` → recusado; qualquer outro (fila,
/// adiado…) → verificando.
String _scanLabel(AppLocalizations l10n, String scanStatus) =>
    switch (scanStatus) {
      'limpa' => l10n.contributionFileScanClean,
      'suspeita' || 'infectada' => l10n.contributionFileScanBlocked,
      _ => l10n.contributionFileScanPending,
    };

/// «campo: atual → proposto» — só existe quando `fields` veio de um
/// `wrong_info/metadata` (`ContributionDraft._fields`); os demais subkinds
/// guardam campos técnicos (ids) que não fazem sentido soltos na tela.
String? _metadataLine(AppLocalizations l10n, Map<String, dynamic> fields) {
  final fieldName = fields['field'] as String?;
  if (fieldName == null) return null;
  MetadataField? field;
  for (final f in MetadataField.values) {
    if (f.name == fieldName) field = f;
  }
  if (field == null) return null;
  final current = fields['current'] as String?;
  final proposed = fields['proposed'] as String? ?? '';
  return '${_metadataFieldLabel(l10n, field)}: ${current ?? '—'} → $proposed';
}

String _metadataFieldLabel(AppLocalizations l10n, MetadataField field) =>
    switch (field) {
      MetadataField.title => l10n.contributeMetadataTitle,
      MetadataField.number => l10n.contributeMetadataNumber,
      MetadataField.author => l10n.contributeMetadataAuthor,
      MetadataField.tonality => l10n.contributeMetadataTonality,
      MetadataField.rhythm => l10n.contributeMetadataRhythm,
      MetadataField.category => l10n.contributeMetadataCategory,
      MetadataField.tags => l10n.contributeMetadataTags,
    };
