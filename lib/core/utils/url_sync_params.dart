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

  /// Identificador da faixa na rota `/audio`.
  static const String audioId = 'audioId';

  /// CSV de audioIds no share de playlist (`shareaudios`).
  static const String shareAudios = 'shareaudios';

  /// Ordem única tipada do share de playlist v2 (`shareitems`, spec A.5).
  ///
  /// CSV de `prefixo:id` (`p` pdf, `c` cifra, `a` áudio, `y` youtube,
  /// `g` gesto, `u` desconhecido). Preserva a ordem intercalada e o tipo, que
  /// [sharePdfs]/[shareAudios] sozinhos perdem; os dois legados continuam
  /// sendo emitidos para apps antigos.
  static const String shareItems = 'shareitems';

  /// Link curto de lista PLPCG (spec short-id-share §1): `shortId`s hex
  /// separados por `-`. Presente ⇒ [shareItems]/[sharePdfs]/[shareAudios]/
  /// [shareName] são ignorados.
  static const String shortItems = 's';

  /// Nome da lista no link curto — obrigatório, marca a URL como share.
  static const String shortName = 'n';

  static const String titulo = 'titulo';
  static const String subtitulo = 'subtitulo';
  static const String validated = 'validated';

  static const String defaultOrdenar = 'numero';
  static const String defaultItensPorPagina = '10';
  static const String defaultPagina = '1';
}
