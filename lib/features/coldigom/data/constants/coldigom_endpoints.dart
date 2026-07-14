/// Endpoints HTTP da API coldigom.
abstract final class ColdigomEndpoints {
  static const praises = '/api/praises';
  static const filterOptions = '/api/praises/filters';
  static const materialKinds = '/api/materials/kinds';
  static const tags = '/api/tags';

  static String praiseDetail(String id) => '/api/praises/$id';
}
