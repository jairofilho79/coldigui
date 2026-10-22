/// Link de compartilhamento do app (playlists, louvores, folhetos).
abstract final class ShareConfig {
  /// Origem dos links compartilhados (`https://plpcg.com`).
  ///
  /// Usa o domínio principal configurado com Universal Links (iOS)
  /// e App Links (Android) para que o link realize deeplink para o app nativo.
  static const String appOrigin = 'https://plpcg.com';
}
