/// UC-13 — Upload admin (fora do MVP).
@Deprecated('UC-13 fora do MVP')
class AdminUploadDatasource {
  const AdminUploadDatasource();

  Future<void> uploadLouvor({
    required List<int> pdfBytes,
    required Map<String, dynamic> metadata,
    required String bearerToken,
  }) {
    throw UnimplementedError('UC-13');
  }
}
