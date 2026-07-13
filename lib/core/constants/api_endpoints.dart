/// Endpoints HTTP do backend Cloudflare (PLPCG).
abstract final class ApiEndpoints {
  /// Catálogo completo — Worker `plpcg-catalog` + D1.
  ///
  /// `GET` → array JSON de louvores (`groupId` incluído).
  /// Ver [CatalogRemoteDatasource.fetchManifest].
  static const String louvoresManifest = '/api/catalog/louvores';

  /// Checksum SHA-256 do catálogo — Worker `plpcg-catalog` + D1.
  ///
  /// `GET` → `200` hex ou `204` se inalterado.
  /// Ver [CatalogRemoteDatasource.fetchChecksum].
  static const String louvoresManifestChecksum = '/api/catalog/checksum';

  /// Sessão Google — Worker `plpcg-catalog` + D1 `users`.
  ///
  /// `POST` + `Authorization: Bearer <id_token>` → perfil (`googleSub`, …).
  static const String authSession = '/api/auth/session';

  /// Playlists do usuário autenticado — Worker + D1 `user_playlists`.
  static const String playlists = '/api/playlists';

  static String playlist(String id) =>
      '/api/playlists/${Uri.encodeComponent(id)}';

  static const String offlineManifest = '/offline-manifest.json';
  static const String uploadLouvor = '/api/upload-louvor';
  static const String assetsPdf = '/assets';
  static const String packagesZip = '/packages';
}
