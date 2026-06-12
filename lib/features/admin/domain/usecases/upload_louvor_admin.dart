/// UC-13 — Upload admin de louvor (fora do MVP)
@Deprecated('UC-13 fora do MVP — FeatureFlags.enableAdminUpload=false')
class UploadLouvorAdmin {
  const UploadLouvorAdmin();

  Future<void> call({
    required List<int> pdfBytes,
    required Map<String, dynamic> metadata,
  }) {
    throw UnimplementedError('UC-13');
  }
}
