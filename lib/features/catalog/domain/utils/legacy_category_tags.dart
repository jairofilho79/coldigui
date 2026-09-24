import 'catalog_tag_hierarchy.dart';

/// Tag raiz das seções da Coletânea no coldigom (spec seções-coletânea §2.1).
const coletaneaRootTag = 'Coletânea';

const _morte = 'Morte Ressurreição e Salvação';
const _santificacao = 'Santificação e Derramamento do Espírito Santo';

/// `praise.category` antigo → nome da subtag de [coletaneaRootTag] (spec
/// seções-coletânea §4.2). A tabela só existe para ler links e filtros
/// gravados antes do fim da categoria; **não** acompanha mudanças futuras de
/// tags.
///
/// «Morte, Ressu… e Salvação» tem vírgula: na URL chega partido pelo CSV
/// (`CatalogFilterState.parseCsv`) em «Morte» e «Ressu… e Salvação», e cada
/// pedaço também leva à seção.
const _legacySections = <String, String>{
  'Clamor': 'Clamor',
  'Consolo e Encorajamento': 'Consolo e Encorajamento',
  'Contra-Capa': 'Contra-Capa',
  'Corinhos': 'Corinhos',
  'Crianças e Adolescentes': 'Crianças e Adolescentes',
  'Dedicação': 'Dedicação',
  'Grupo de Louvor': 'Grupo de Louvor',
  'Invocação e Comunhão': 'Invocação e Comunhão',
  'Louvor': 'Louvor',
  'Salmos de Louvor': 'Salmos de Louvor',
  'Volta de Jesus e Eternidade': 'Volta de Jesus e Eternidade',
  'Morte, Ressureição e Salvação': _morte,
  'Morte, Ressurreição e Salvação': _morte,
  'Morte': _morte,
  'Ressureição e Salvação': _morte,
  'Ressurreição e Salvação': _morte,
  'Santificação e Derramamento': _santificacao,
  'Santificação e Derramamento do Espírito Santo': _santificacao,
};

/// Converte valores antigos de categoria (inteiros, da pref, ou pedaços do
/// CSV da URL) nas subtags `Coletânea · <seção>`, somadas à raiz
/// [coletaneaRootTag] sempre que pelo menos um valor converte (a subtag sem
/// o pai marcado não aparece na seção Tags — ela só refina o pai já
/// marcado; ver `catalogTagsRefined`).
///
/// Coleções (Avulso, Avulsos, Avulso Cias, Avulsos das Senhoras) e qualquer
/// valor desconhecido são descartados em silêncio (spec §7).
Set<String> legacyCategoryToTags(Iterable<String> values) {
  final tags = <String>{};
  for (final raw in values) {
    final section = _legacySections[raw.trim()];
    if (section != null) {
      tags.add('$coletaneaRootTag$catalogTagHierarchySeparator$section');
    }
  }
  if (tags.isNotEmpty) {
    tags.add(coletaneaRootTag);
  }
  return tags;
}
