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
  String toString() => 'ZipDownloadSizeMismatchException(filename: $filename, '
      'expected: $expected, actual: $actual)';
}

/// Bulk download cancelado pelo usuário.
class OfflineBulkCancelledException implements Exception {
  const OfflineBulkCancelledException();

  @override
  String toString() => 'OfflineBulkCancelledException';
}
