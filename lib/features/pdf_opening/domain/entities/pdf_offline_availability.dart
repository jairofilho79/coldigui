/// Disponibilidade offline de um PDF no índice Isar (UC-04 badge).
enum PdfOfflineAvailability {
  /// Ausente do índice offline.
  notAvailable,

  /// No índice com `isPersistent = false` — pode ser removido pelo LRU.
  cachedLru,

  /// No índice com `isPersistent = true` — download garantido offline.
  persistentOffline,
}
