import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/contribution_kind.dart';

/// `Wrap` de `ChoiceChip` para os 5 [ContributionKind] (spec §6.2 item 1).
/// Densidade negativa + fonte menor: com o subkind de bug (8 chips) logo
/// abaixo, o formulário inteiro precisa caber sem rolar nos testes de
/// widget — ver o comentário em `ContributeScreen` sobre o cartão de
/// dispositivo.
class KindChips extends StatelessWidget {
  const KindChips({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final ContributionKind selected;
  final ValueChanged<ContributionKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        for (final kind in ContributionKind.values)
          ChoiceChip(
            key: Key('kind-${kind.wireName}'),
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            label: Text(
              _kindLabel(l10n, kind),
              style: const TextStyle(fontSize: 12),
            ),
            selected: selected == kind,
            onSelected: (_) => onSelected(kind),
          ),
      ],
    );
  }

  static String _kindLabel(AppLocalizations l10n, ContributionKind kind) =>
      switch (kind) {
        ContributionKind.bug => l10n.contributeKindBug,
        ContributionKind.wrongInfo => l10n.contributeKindWrongInfo,
        ContributionKind.content => l10n.contributeKindContent,
        ContributionKind.improvement => l10n.contributeKindImprovement,
        ContributionKind.other => l10n.contributeKindOther,
      };
}

/// `Wrap` de `ChoiceChip` dos subkinds de [kind] (spec §6.2 item 2) — só
/// chamado quando `subkindsOf(kind)` não é vazio.
class SubkindChips extends StatelessWidget {
  const SubkindChips({
    required this.kind,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final ContributionKind kind;
  final ContributionSubkind? selected;
  final ValueChanged<ContributionSubkind> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        for (final subkind in subkindsOf(kind))
          ChoiceChip(
            key: Key('subkind-${subkind.wireName}'),
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            label: Text(
              _subkindLabel(l10n, subkind),
              style: const TextStyle(fontSize: 12),
            ),
            selected: selected == subkind,
            onSelected: (_) => onSelected(subkind),
          ),
      ],
    );
  }

  static String _subkindLabel(
    AppLocalizations l10n,
    ContributionSubkind subkind,
  ) => switch (subkind) {
    ContributionSubkind.bugScreen => l10n.contributeSubkindBugScreen,
    ContributionSubkind.bugReader => l10n.contributeSubkindBugReader,
    ContributionSubkind.bugAudio => l10n.contributeSubkindBugAudio,
    ContributionSubkind.bugSearch => l10n.contributeSubkindBugSearch,
    ContributionSubkind.bugOffline => l10n.contributeSubkindBugOffline,
    ContributionSubkind.bugLogin => l10n.contributeSubkindBugLogin,
    ContributionSubkind.bugPlaylistLive =>
      l10n.contributeSubkindBugPlaylistLive,
    ContributionSubkind.bugOther => l10n.contributeSubkindBugOther,
    ContributionSubkind.wrongMetadata => l10n.contributeSubkindWrongMetadata,
    ContributionSubkind.wrongLyrics => l10n.contributeSubkindWrongLyrics,
    ContributionSubkind.wrongMaterial => l10n.contributeSubkindWrongMaterial,
    ContributionSubkind.wrongKind => l10n.contributeSubkindWrongKind,
    ContributionSubkind.duplicate => l10n.contributeSubkindDuplicate,
    ContributionSubkind.addMaterial => l10n.contributeSubkindAddMaterial,
    ContributionSubkind.addPraise => l10n.contributeSubkindAddPraise,
    ContributionSubkind.replaceMaterial =>
      l10n.contributeSubkindReplaceMaterial,
    ContributionSubkind.remove => l10n.contributeSubkindRemove,
    ContributionSubkind.feature => l10n.contributeSubkindFeature,
    ContributionSubkind.behavior => l10n.contributeSubkindBehavior,
  };
}
