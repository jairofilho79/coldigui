/// Endpoints HTTP da API coldigom.
abstract final class ColdigomEndpoints {
  static const praises = '/api/praises';

  static String praiseDetail(String id) => '/api/praises/$id';
}
