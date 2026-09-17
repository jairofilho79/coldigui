import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/domain/entities/louvor_data_source.dart';
import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../../../coldigom/domain/entities/coldigom_praise_metadata.dart';
import '../../../material_kind_prefs/presentation/providers/coldigom_material_kinds_provider.dart';
import '../../domain/entities/contribution_kind.dart';

/// «Sobre qual material?» (spec §6.2 item 3) — só quando há `praiseId`:
/// junta PDFs (PLPCG + coldigom), áudios e cifras do mesmo `groupId`.
class MaterialDropdown extends ConsumerWidget {
  const MaterialDropdown({
    required this.praiseId,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String praiseId;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final lookup = ref.watch(catalogMaterialLookupProvider);
    final options = <(String id, String label)>[
      for (final l in lookup.plpcgLouvoresByPdfId.values)
        if (l.groupId == praiseId) (l.pdfId, l.categoria),
      for (final l in lookup.coldigomLouvoresByPdfId.values)
        if (l.groupId == praiseId) (l.pdfId, l.categoria),
      for (final a in lookup.audioTracksById.values)
        if (a.groupId == praiseId) (a.audioId, a.categoria),
      for (final c in lookup.chordsById.values)
        if (c.groupId == praiseId) (c.chordId, c.categoria),
    ];
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(labelText: l10n.contributeMaterialLabel),
      items: [
        DropdownMenuItem(
          value: null,
          child: Text(l10n.contributeMaterialWhole),
        ),
        for (final option in options)
          DropdownMenuItem(value: option.$1, child: Text(option.$2)),
      ],
      onChanged: onChanged,
    );
  }
}

/// Campo/valor atual/valor correto de `wrong_info/metadata` (spec §6.2 item 4).
class MetadataFields extends ConsumerWidget {
  const MetadataFields({
    required this.praiseId,
    required this.field,
    required this.current,
    required this.proposed,
    required this.onFieldChanged,
    required this.onCurrentChanged,
    required this.onProposedChanged,
    super.key,
  });

  final String? praiseId;
  final MetadataField? field;
  final String? current;
  final String? proposed;
  final ValueChanged<MetadataField> onFieldChanged;
  final ValueChanged<String> onCurrentChanged;
  final ValueChanged<String> onProposedChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final lookup = ref.watch(catalogMaterialLookupProvider);
    final meta = praiseId != null ? lookup.praiseMeta(praiseId!) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<MetadataField>(
          initialValue: field,
          decoration: InputDecoration(labelText: l10n.contributeMetadataField),
          items: [
            for (final f in MetadataField.values)
              DropdownMenuItem(
                value: f,
                child: Text(_metadataFieldLabel(l10n, f)),
              ),
          ],
          onChanged: (f) {
            if (f == null) return;
            onFieldChanged(f);
            final prefill = _prefillFor(f, meta);
            if (prefill != null) onCurrentChanged(prefill);
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: current,
          decoration: InputDecoration(
            labelText: l10n.contributeMetadataCurrent,
          ),
          onChanged: onCurrentChanged,
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('contribute-proposed'),
          initialValue: proposed,
          decoration: InputDecoration(
            labelText: l10n.contributeMetadataProposed,
          ),
          onChanged: onProposedChanged,
        ),
      ],
    );
  }

  /// Prefill de "Valor atual" a partir dos metadados em cache do praise —
  /// só para os campos que o cache conhece (spec: `name/tonality/author/rhythm`).
  static String? _prefillFor(
    MetadataField field,
    ColdigomPraiseMetadata? meta,
  ) {
    if (meta == null) return null;
    return switch (field) {
      MetadataField.title => meta.name,
      MetadataField.tonality => meta.tonality,
      MetadataField.author => meta.author,
      MetadataField.rhythm => meta.rhythm,
      MetadataField.number ||
      MetadataField.category ||
      MetadataField.tags => null,
    };
  }

  static String _metadataFieldLabel(
    AppLocalizations l10n,
    MetadataField field,
  ) => switch (field) {
    MetadataField.title => l10n.contributeMetadataTitle,
    MetadataField.number => l10n.contributeMetadataNumber,
    MetadataField.author => l10n.contributeMetadataAuthor,
    MetadataField.tonality => l10n.contributeMetadataTonality,
    MetadataField.rhythm => l10n.contributeMetadataRhythm,
    MetadataField.category => l10n.contributeMetadataCategory,
    MetadataField.tags => l10n.contributeMetadataTags,
  };
}

/// «É o mesmo que» de `wrong_info/duplicate` (spec §6.2 item 5): busca livre
/// com `Autocomplete` sobre o catálogo em memória — sem acoplar com a Home.
class DuplicateField extends ConsumerWidget {
  const DuplicateField({required this.onSelected, super.key});

  final void Function({
    required String praiseId,
    required ContributionSource source,
  })
  onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final lookup = ref.watch(catalogMaterialLookupProvider);
    return Autocomplete<Louvor>(
      optionsBuilder: (textEditingValue) {
        final q = textEditingValue.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<Louvor>.empty();
        final all = [
          ...lookup.plpcgLouvoresByPdfId.values,
          ...lookup.coldigomLouvoresByPdfId.values,
        ];
        return all
            .where(
              (l) =>
                  l.numero.toLowerCase().contains(q) ||
                  l.nome.toLowerCase().contains(q),
            )
            .take(8);
      },
      displayStringForOption: (l) => '${l.numero} — ${l.nome}',
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          key: const Key('contribute-duplicate'),
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(labelText: l10n.contributeDuplicateOf),
        );
      },
      onSelected: (l) => onSelected(
        praiseId: l.groupId,
        source: l.source == LouvorDataSource.coldigom
            ? ContributionSource.coldigom
            : ContributionSource.plpcg,
      ),
    );
  }
}

/// Tipo de material sugerido de `content` (spec §6.2 item 6) — opcional.
class SuggestedKindDropdown extends ConsumerWidget {
  const SuggestedKindDropdown({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final kindsAsync = ref.watch(coldigomMaterialKindsProvider);
    final kinds = kindsAsync.asData?.value ?? const [];
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(labelText: l10n.contributeSuggestedKind),
      items: [
        for (final kind in kinds)
          DropdownMenuItem(value: kind.id, child: Text(kind.name)),
      ],
      onChanged: onChanged,
    );
  }
}
