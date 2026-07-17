/// Endpoints HTTP da API coldigom.
abstract final class ColdigomEndpoints {
  static const praises = '/api/praises';

  /// Listagem leve para o app PLPCG (materials slim, sem texto da letra).
  static const plpcgPraises = '/api/plpcg/praises';
  static const filterOptions = '/api/praises/filters';
  static const materialKinds = '/api/materials/kinds';
  static const tags = '/api/tags';

  static String praiseDetail(String id) => '/api/praises/$id';
}
