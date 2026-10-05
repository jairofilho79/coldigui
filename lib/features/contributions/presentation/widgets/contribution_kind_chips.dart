import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/contribution_kind.dart';
import '../utils/contribution_labels.dart';

/// `Wrap` de `ChoiceChip` para os 5 [ContributionKind] (spec §6.2 item 1).
/// Tamanho padrão do Material (alvo de toque ≥48dp) — o telefone é a
/// plataforma principal; a tela rola (`SingleChildScrollView`) em vez de
/// espremer os chips para caber sem rolagem.
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
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final kind in ContributionKind.values)
          ChoiceChip(
            key: Key('kind-${kind.wireName}'),
            label: Text(contributionKindLabel(l10n, kind)),
            selected: selected == kind,
            showCheckmark: false,
            onSelected: (_) => onSelected(kind),
          ),
      ],
    );
  }
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
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final subkind in subkindsOf(kind))
          ChoiceChip(
            key: Key('subkind-${subkind.wireName}'),
            label: Text(contributionSubkindLabel(l10n, subkind)),
            selected: selected == subkind,
            showCheckmark: false,
            onSelected: (_) => onSelected(subkind),
          ),
      ],
    );
  }
}
