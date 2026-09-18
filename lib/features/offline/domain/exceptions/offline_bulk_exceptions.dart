/// Espaço em disco insuficiente para o download em massa (Coldigom UC-09).
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
