/// Endpoints HTTP do backend Cloudflare (PLPCG).
abstract final class ApiEndpoints {
  static const String louvoresManifest = '/louvores-manifest.json';
  static const String louvoresManifestChecksum = '/louvores-manifest.sha256';
  static const String offlineManifest = '/offline-manifest.json';
  static const String uploadLouvor = '/api/upload-louvor';
  static const String assetsPdf = '/assets';
  static const String packagesZip = '/packages';
}
