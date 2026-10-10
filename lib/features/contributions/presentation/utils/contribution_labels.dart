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

/// Rótulo humano de [subkind] — usado nos chips do formulário e na
/// geração do título automático.
String contributionSubkindLabel(
  AppLocalizations l10n,
  ContributionSubkind subkind,
) => switch (subkind) {
  ContributionSubkind.bugScreen => l10n.contributeSubkindBugScreen,
  ContributionSubkind.bugReader => l10n.contributeSubkindBugReader,
  ContributionSubkind.bugAudio => l10n.contributeSubkindBugAudio,
  ContributionSubkind.bugSearch => l10n.contributeSubkindBugSearch,
  ContributionSubkind.bugOffline => l10n.contributeSubkindBugOffline,
  ContributionSubkind.bugLogin => l10n.contributeSubkindBugLogin,
  ContributionSubkind.bugPlaylistLive => l10n.contributeSubkindBugPlaylistLive,
  ContributionSubkind.bugOther => l10n.contributeSubkindBugOther,
  ContributionSubkind.wrongMetadata => l10n.contributeSubkindWrongMetadata,
  ContributionSubkind.wrongLyrics => l10n.contributeSubkindWrongLyrics,
  ContributionSubkind.wrongMaterial => l10n.contributeSubkindWrongMaterial,
  ContributionSubkind.wrongKind => l10n.contributeSubkindWrongKind,
  ContributionSubkind.duplicate => l10n.contributeSubkindDuplicate,
  ContributionSubkind.addMaterial => l10n.contributeSubkindAddMaterial,
  ContributionSubkind.addPraise => l10n.contributeSubkindAddPraise,
  ContributionSubkind.replaceMaterial => l10n.contributeSubkindReplaceMaterial,
  ContributionSubkind.remove => l10n.contributeSubkindRemove,
  ContributionSubkind.feature => l10n.contributeSubkindFeature,
  ContributionSubkind.behavior => l10n.contributeSubkindBehavior,
};

/// Gera o título automático baseado na combinação de [kind] ("O que você quer contar")
/// e [subkind] ("Sobre o quê"). Retorna string vazia para [ContributionKind.other] ou
/// enquanto [subkind] não for selecionado.
String contributionAutoTitle(
  AppLocalizations l10n,
  ContributionKind kind,
  ContributionSubkind? subkind,
) {
  if (kind == ContributionKind.other || subkind == null) {
    return '';
  }
  return '${contributionKindLabel(l10n, kind)} - ${contributionSubkindLabel(l10n, subkind)}';
}

/// Rótulo humano de [field] (`wrong_info/metadata`) — usado no formulário e
/// no detalhe da contribuição; antes repetido nos dois lugares.
String metadataFieldLabel(AppLocalizations l10n, MetadataField field) =>
    switch (field) {
      MetadataField.title => l10n.contributeMetadataTitle,
      MetadataField.number => l10n.contributeMetadataNumber,
      MetadataField.author => l10n.contributeMetadataAuthor,
      MetadataField.tonality => l10n.contributeMetadataTonality,
      MetadataField.rhythm => l10n.contributeMetadataRhythm,
      MetadataField.tags => l10n.contributeMetadataTags,
    };

/// Gera um título conciso a partir do corpo do texto (primeira linha ou sentença, até 80 caracteres).
String deriveTitleFromBody(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return '';
  final firstLine = trimmed.split('\n').first.trim();
  final candidate = firstLine.isNotEmpty ? firstLine : trimmed;
  if (candidate.length <= 80) return candidate;
  return '${candidate.substring(0, 77)}...';
}

