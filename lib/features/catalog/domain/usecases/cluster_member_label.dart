import '../../../../core/utils/louvor_search_tokens.dart';
import '../entities/louvor_group.dart';

/// Etiqueta dourada do gomo de [member] no amendoim de [allMembers] (spec
/// louvores-agrupados §5): as tags que ele tem e que nem todos têm, em ordem
/// alfabética, juntas por « · ». Sem nenhuma, a primeira tag dele cortada
/// antes do primeiro « · » («Coletânea · Clamor» → «Coletânea»). Sem tag
/// nenhuma, `null` (sem etiqueta).
///
/// Ordena as tags aqui porque a ordem que chega não serve: o dump manda
/// `ORDER BY label` e a busca remota um `GROUP_CONCAT` sem ordem.
String? clusterMemberLabel(LouvorGroup member, List<LouvorGroup> allMembers) {
  final own = _tagsOf(member).toList()..sort(_compareTags);
  if (own.isEmpty) return null;

  Set<String>? common;
  for (final other in allMembers) {
    final tags = _tagsOf(other);
    common = common == null ? tags : common.intersection(tags);
  }
  final distinct = [
    for (final tag in own)
      if (!(common ?? const <String>{}).contains(tag)) tag,
  ];
  if (distinct.isNotEmpty) return distinct.join(' · ');

  final first = own.first;
  final cut = first.indexOf(' · ');
  return cut == -1 ? first : first.substring(0, cut);
}

Set<String> _tagsOf(LouvorGroup group) => {
  for (final tag in group.coldigomMeta?.tagNames ?? const <String>[])
    if (tag.trim().isNotEmpty) tag.trim(),
};

int _compareTags(String a, String b) {
  final byNorm = LouvorSearchTokens.normalize(a)
      .compareTo(LouvorSearchTokens.normalize(b));
  return byNorm != 0 ? byNorm : a.compareTo(b);
}
