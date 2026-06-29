/// Evita refresh repetido de viewport para a mesma página visível.
class PdfReaderViewportPolicy {
  PdfReaderViewportPolicy({int? initialPage})
      : _lastRefreshedPage = initialPage;

  int? _lastRefreshedPage;

  /// Retorna `true` se um refresh deve ser agendado para [pageNumber].
  bool shouldScheduleRefresh(int pageNumber) {
    if (_lastRefreshedPage == pageNumber) return false;
    _lastRefreshedPage = pageNumber;
    return true;
  }
}

/// Evita múltiplos reattachs pós-frame para o mesmo ciclo.
class PdfReattachGuard {
  var _scheduled = false;

  bool trySchedule() {
    if (_scheduled) return false;
    _scheduled = true;
    return true;
  }

  void complete() {
    _scheduled = false;
  }
}
