/// Distingue path local (cache `plpcg_pdfs/`) de origens remotas (UC-04 Fase 3.4).
///
/// Espelha a lógica de [PdfSourceResolver] sem acoplar `pdf_reader/data`.
///
/// Retorna `false` para: `http(s)://`, `asset:`, `/assets/…`, `assets/…`, vazio.
/// Retorna `true` para paths de filesystem (ex.: `/var/…/plpcg_pdfs/Col/001.pdf`).
///
/// Consumido por [SharePdf] e [SavePdf] para fast path sem [PdfBytesDatasource].
bool isLocalPdfPath(String filePath) {
  final trimmed = filePath.trim();
  if (trimmed.isEmpty) return false;

  if (trimmed.startsWith('asset:')) return false;

  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return false;
  }

  final normalized = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
  if (normalized.startsWith('assets/')) return false;

  return true;
}
