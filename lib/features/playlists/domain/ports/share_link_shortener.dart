/// Porta do encurtador de link de compartilhamento (D7, spec C.2).
///
/// A implementação Dio mora em `playlists/data`
/// (`ShareLinkShortenerRemote`) e fala com o Worker `POST /api/links`.
abstract interface class ShareLinkShortener {
  /// Encurta [query] (a query string do share, com `shareitems=…`) e devolve
  /// a URL curta (`https://plpcg.com/l/<code>`).
  ///
  /// Lança em qualquer erro — rede, timeout, resposta inesperada — sem
  /// tentar decidir sozinha o que fazer: quem chama ([GeneratePlaylistShareUrl])
  /// é quem decide cair na URL longa.
  Future<String> shorten(String query);
}
