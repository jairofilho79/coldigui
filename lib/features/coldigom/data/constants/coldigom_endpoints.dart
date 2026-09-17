/// Endpoints HTTP da API coldigom.
abstract final class ColdigomEndpoints {
  static const praises = '/api/praises';

  /// Listagem leve para o app PLPCG (materials slim, sem texto da letra).
  static const plpcgPraises = '/api/plpcg/praises';

  /// Dump compacto do catálogo inteiro para o Isar local (ETag + 304).
  static const plpcgCatalog = '/api/plpcg/catalog';
  static const filterOptions = '/api/praises/filters';
  static const materialKinds = '/api/materials/kinds';
  static const tags = '/api/tags';

  static String praiseDetail(String id) => '/api/praises/$id';

  /// Material types (pdf/chord/...) que de fato existem para um material
  /// kind — calculado sob demanda pelo Worker, sem tabela própria no app.
  static String materialTypesForKind(String kindId) =>
      '$materialKinds/$kindId/types';

  /// Contribuições da comunidade (Bearer `sess_…`).
  static const contributions = '/api/contributions';
  static const contributionsMine = '/api/contributions/mine';
  static String contribution(String id) => '/api/contributions/$id';
}
