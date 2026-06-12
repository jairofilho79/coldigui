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

/// Bulk download cancelado pelo usuário.
class OfflineBulkCancelledException implements Exception {
  const OfflineBulkCancelledException();

  @override
  String toString() => 'OfflineBulkCancelledException';
}
