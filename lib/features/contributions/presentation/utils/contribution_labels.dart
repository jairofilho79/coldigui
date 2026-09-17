import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/contribution_kind.dart';

/// Rótulo humano de [kind] — usado nos chips do formulário, em «Minhas
/// contribuições» e no detalhe; antes repetido em três `switch` privados.
String contributionKindLabel(AppLocalizations l10n, ContributionKind kind) =>
    switch (kind) {
      ContributionKind.bug => l10n.contributeKindBug,
      ContributionKind.wrongInfo => l10n.contributeKindWrongInfo,
      ContributionKind.content => l10n.contributeKindContent,
      ContributionKind.improvement => l10n.contributeKindImprovement,
      ContributionKind.other => l10n.contributeKindOther,
    };

/// Rótulo humano de [field] (`wrong_info/metadata`) — usado no formulário e
/// no detalhe da contribuição; antes repetido nos dois lugares.
String metadataFieldLabel(AppLocalizations l10n, MetadataField field) =>
    switch (field) {
      MetadataField.title => l10n.contributeMetadataTitle,
      MetadataField.number => l10n.contributeMetadataNumber,
      MetadataField.author => l10n.contributeMetadataAuthor,
      MetadataField.tonality => l10n.contributeMetadataTonality,
      MetadataField.rhythm => l10n.contributeMetadataRhythm,
      MetadataField.category => l10n.contributeMetadataCategory,
      MetadataField.tags => l10n.contributeMetadataTags,
    };
