/// Query params sincronizados com estado (§2.5 MAPEAMENTO).
abstract final class UrlSyncParams {
  static const String pesquisa = 'pesquisa';
  static const String materiais = 'materiais';
  static const String arranjo = 'arranjo';
  static const String arranjoEspecial = 'arranjoEspecial';
  static const String ordenar = 'ordenar';
  static const String itensPorPagina = 'itensPorPagina';
  static const String pagina = 'pagina';

  /// Biblioteca: `plpcg` (omitido) | `coldigom`.
  static const String fonte = 'fonte';

  /// Filtros Coldigom (CSV) — espelham query params da API.
  static const String tonality = 'tonality';
  static const String rhythm = 'rhythm';
  static const String category = 'category';
  static const String tags = 'tags';
  static const String materialKinds = 'materialKinds';
  static const String sharePdfs = 'sharepdfs';
  static const String shareName = 'sharename';
  static const String file = 'file';

  /// Identificador do louvor na rota `/leitor` — habilita carousel in-reader (4.7).
  static const String pdfId = 'pdfId';
  static const String titulo = 'titulo';
  static const String subtitulo = 'subtitulo';
  static const String validated = 'validated';

  static const String defaultOrdenar = 'numero';
  static const String defaultItensPorPagina = '10';
  static const String defaultPagina = '1';
}
