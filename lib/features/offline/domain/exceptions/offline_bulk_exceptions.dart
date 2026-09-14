/// Espaço em disco insuficiente para o bulk UC-09.
class InsufficientDiskSpaceException implements Exception {
  const InsufficientDiskSpaceException({
    required this.requiredBytes,
    required this.availableBytes,
  });

  final int requiredBytes;
  final int? availableBytes;

  @override
  String toString() =>
      'InsufficientDiskSpaceException(required: $requiredBytes, available: $availableBytes)';
}

/// Tamanho do `.tmp` diverge de `part.size` após download bulk.
class ZipDownloadSizeMismatchException implements Exception {
  const ZipDownloadSizeMismatchException({
    required this.expected,
    required this.actual,
    required this.filename,
  });

  final int expected;
  final int actual;
  final String filename;

  @override
  String toString() =>
      'ZipDownloadSizeMismatchException(filename: $filename, '
      'expected: $expected, actual: $actual)';
}

/// Download de ZIP interrompido por cancelamento do usuário (não é falha).
///
/// Distinto de [ZipDownloadStalledException]: nunca é retentado — o usuário
/// pediu para parar. O usecase converte em [OfflineBulkCancelledException].
class ZipDownloadCancelledException implements Exception {
  const ZipDownloadCancelledException();

  @override
  String toString() => 'ZipDownloadCancelledException';
}

/// Conexão parada: nenhum byte recebido dentro do watchdog inter-chunk.
///
/// Conta como tentativa retryável — o cancelamento interno do request é
/// detalhe de implementação, não um cancelamento do usuário.
class ZipDownloadStalledException implements Exception {
  const ZipDownloadStalledException(this.timeout);

  final Duration timeout;

  @override
  String toString() =>
      'ZipDownloadStalledException(sem bytes por ${timeout.inSeconds}s)';
}

/// ZIP baixado não pôde ser lido (corrompido/truncado) — arquivo já apagado.
class ZipCorruptedException implements Exception {
  const ZipCorruptedException(this.path, [this.cause]);

  final String path;
  final Object? cause;

  @override
  String toString() => 'ZipCorruptedException(path: $path, cause: $cause)';
}

/// Bulk download cancelado pelo usuário.
class OfflineBulkCancelledException implements Exception {
  const OfflineBulkCancelledException();

  @override
  String toString() => 'OfflineBulkCancelledException';
}

/// Falha ao gravar PDF no storage (web — Cache API) não relacionada a quota.
class PdfStorageWriteException implements Exception {
  const PdfStorageWriteException(this.message);

  final String message;

  @override
  String toString() => 'PdfStorageWriteException($message)';
}

/// Falha ao gravar áudio no storage (web — Cache API) não relacionada a quota.
class AudioStorageWriteException implements Exception {
  const AudioStorageWriteException(this.message);

  final String message;

  @override
  String toString() => 'AudioStorageWriteException($message)';
}
