/// Query params sincronizados com estado (§2.5 MAPEAMENTO).
abstract final class UrlSyncParams {
  static const String pesquisa = 'pesquisa';
  static const String ordenar = 'ordenar';
  static const String itensPorPagina = 'itensPorPagina';
  static const String pagina = 'pagina';

  /// Filtros do catálogo (CSV), nas rotas `/` e `/biblioteca` (spec fim-fonte
  /// §2.5). [tags] leva **nomes** de tag; [materialKinds], ids de kind.
  static const String tonality = 'tonality';
  static const String rhythm = 'rhythm';
  static const String category = 'category';
  static const String tags = 'tags';
  static const String materialKinds = 'materialKinds';

  /// Legado — link longo antigo; só reconhecido (spec fim-fonte-plpcg §4.4).
  static const String sharePdfs = 'sharepdfs';

  /// Legado — link longo antigo; só reconhecido (spec fim-fonte-plpcg §4.4).
  static const String shareName = 'sharename';

  static const String file = 'file';

  /// Identificador do louvor na rota `/leitor` — habilita carousel in-reader (4.7).
  static const String pdfId = 'pdfId';

  /// Identificador da faixa na rota `/audio`.
  static const String audioId = 'audioId';

  /// Identificador do praise Coldigom na rota `/letra`.
  static const String praiseId = 'praiseId';

  /// Legado — CSV de audioIds do link longo antigo; só reconhecido.
  static const String shareAudios = 'shareaudios';

  /// Legado — ordem tipada do link longo antigo (`shareitems`); só reconhecido.
  static const String shareItems = 'shareitems';

  /// Legado — link curto por material (`?s=`, spec short-id-share). Só é
  /// reconhecido para avisar que o link é antigo (spec fim-fonte-plpcg §4.4).
  static const String shortItems = 's';

  /// Nome da lista no link por praise (`?p=…&n=…`) — obrigatório.
  static const String shortName = 'n';

  /// Link por praise (spec fim-fonte-plpcg §4.1): `shortId`s de **praise**
  /// hex separados por `-`, na ordem da lista (repetidos permitidos).
  static const String praiseItems = 'p';

  static const String titulo = 'titulo';
  static const String subtitulo = 'subtitulo';
  static const String validated = 'validated';

  static const String defaultOrdenar = 'numero';
  static const String defaultItensPorPagina = '10';
  static const String defaultPagina = '1';
}
