import 'package:isar_plus/isar_plus.dart';

part 'offline_pdf_index.g.dart';

/// Índice offline pdfId → path no filesystem (UC-09/10).
///
/// Fonte de verdade do cache local (Fase 3). Lookup O(1) via [ResolvePdfForReader].
@Collection()
class OfflinePdfIndex {
  int id = 0;

  @Index(unique: true)
  late String pdfId;

  /// Path absoluto do PDF em `documents/plpcg_pdfs/`.
  late String storagePath;

  /// Classificação do louvor (ex.: `ColAdultos`) — agregação UC-09/10.
  late String category;

  /// Tamanho em bytes no último upsert — stats sem scan disco.
  late int fileSize;

  /// Timestamp do último upsert bem-sucedido.
  late DateTime downloadedAt;

  /// Timestamp do último lookup/upsert bem-sucedido — base do LRU (backlog #10).
  ///
  /// Registros legados sem valor usam [downloadedAt] na ordenação de eviction.
  DateTime? lastAccessedAt;

  /// `true` = bulk ou "baixar faltantes"; `false` = cache on-demand (LRU).
  bool isPersistent = false;
}
