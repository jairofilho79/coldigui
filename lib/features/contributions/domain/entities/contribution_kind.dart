/// Taxonomia das contribuições (spec §3.1). Os `wireName` são o contrato com
/// o coldigom-api — mudar aqui sem mudar lá quebra o `400 invalid_kind`.
enum ContributionKind {
  bug('bug'),
  wrongInfo('wrong_info'),
  content('content'),
  improvement('improvement'),
  other('other');

  const ContributionKind(this.wireName);
  final String wireName;
}

enum ContributionSubkind {
  bugScreen(ContributionKind.bug, 'screen'),
  bugReader(ContributionKind.bug, 'reader'),
  bugAudio(ContributionKind.bug, 'audio'),
  bugSearch(ContributionKind.bug, 'search'),
  bugOffline(ContributionKind.bug, 'offline'),
  bugLogin(ContributionKind.bug, 'login'),
  bugPlaylistLive(ContributionKind.bug, 'playlist_live'),
  bugOther(ContributionKind.bug, 'other'),
  wrongMetadata(ContributionKind.wrongInfo, 'metadata'),
  wrongLyrics(ContributionKind.wrongInfo, 'lyrics'),
  wrongMaterial(ContributionKind.wrongInfo, 'wrong_material'),
  wrongKind(ContributionKind.wrongInfo, 'wrong_kind'),
  duplicate(ContributionKind.wrongInfo, 'duplicate'),
  addMaterial(ContributionKind.content, 'add_material'),
  addPraise(ContributionKind.content, 'add_praise'),
  replaceMaterial(ContributionKind.content, 'replace_material'),
  remove(ContributionKind.content, 'remove'),
  feature(ContributionKind.improvement, 'feature'),
  behavior(ContributionKind.improvement, 'behavior');

  const ContributionSubkind(this.kind, this.wireName);
  final ContributionKind kind;
  final String wireName;
}

/// Subkinds de um kind, na ordem de declaração; `other` não tem nenhum.
List<ContributionSubkind> subkindsOf(ContributionKind kind) => [
  for (final s in ContributionSubkind.values)
    if (s.kind == kind) s,
];

/// Campo de metadado alvo de um `wrong_info/metadata` — o nome do enum já é
/// o `wireName` esperado pelo servidor.
enum MetadataField { title, number, author, tonality, rhythm, category, tags }

enum ContributionSource {
  coldigom('coldigom'),
  plpcg('plpcg');

  const ContributionSource(this.wireName);
  final String wireName;
}
