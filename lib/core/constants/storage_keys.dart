/// Chaves de [SharedPreferences] e flags leves.
abstract final class StorageKeys {
  static const String pdfPreferredFitMode = 'pdfPreferredFitMode';
  static const String perfDebug = 'plpcjf_perf_debug';

  /// Versão do layout offline nativo — [MigrateOfflineStorage] (Fase 3.6).
  static const String offlineStorageVersion = 'offlineStorageVersion';

  /// Timestamp (epoch ms) do último reconcile global UC-10 (backlog #12).
  static const String lastReconcileAt = 'lastReconcileAt';

  /// Corpo da letra no leitor de cifras, em px.
  static const String chordReaderFontSize = 'chordReaderFontSize';

  /// Corpo da letra no leitor de gestos (`double`).
  static const String gestureReaderFontSize = 'gestureReaderFontSize';

  /// Claro/escuro do leitor de gestos (`light` | `dark`).
  static const String gestureReaderMode = 'gestureReaderMode';

  /// Leitura linear do leitor de gestos (`bool`, default `true`).
  static const String gestureReaderLinear = 'gestureReaderLinear';

  /// Velocidade do autoscroll do leitor de gestos (`int` 1–5).
  static const String gestureAutoscrollSpeed = 'gestureAutoscrollSpeed';

  /// Claro/escuro do leitor de cifras (`light` | `dark`).
  static const String chordReaderMode = 'chordReaderMode';

  /// Filtros do catálogo (JSON v2: tom, ritmo, categoria, tags, tipos de
  /// material) — C13, spec fim-fonte §2.2.
  static const String catalogFilters = 'catalogFilters';

  /// Itens por página da Biblioteca (UC-03) — C13.
  static const String libraryItemsPerPage = 'libraryItemsPerPage';

  /// Ids de material abertos recentemente na Home, JSON (C4).
  static const String recentlyOpened = 'recentlyOpened';

  /// LRU (50) da última página vista por `pdfId` — JSON `[{"id":..,"p":..}]`
  /// (UC-11 / spec A.3 C8, "lembrar última página").
  static const String pdfLastPages = 'pdfLastPages';

  /// Última posição do player de áudio, JSON `{"trackId":..,"positionMs":..}`
  /// (spec B.4 C12, retomar posição no boot).
  static const String audioLastPosition = 'audioLastPosition';

  /// ETag do último dump `GET /api/plpcg/catalog` gravado no Isar.
  static const String coldigomCatalogEtag = 'coldigomCatalogEtag';

  /// Timestamp ISO-8601 do último sync do catálogo Coldigom (200 ou 304).
  static const String coldigomCatalogSyncedAt = 'coldigomCatalogSyncedAt';

  /// Quantos praises o último sync gravou — linha de estado do `/offline`.
  static const String coldigomCatalogCount = 'coldigomCatalogCount';

  /// Corpo da letra no leitor de letras `/letra` (`double`).
  static const String lyricsReaderFontSize = 'lyricsReaderFontSize';

  /// Kinds Coldigom marcados para download no /offline (O11) — JSON array.
  static const String offlineColdigomKindIds = 'offlineColdigomKindIds';
}
