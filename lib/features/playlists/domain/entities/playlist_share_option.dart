/// Modo de compartilhamento escolhido no bottom sheet (UC-07/UC-08).
enum PlaylistShareOption {
  /// Só URL da playlist.
  link,

  /// Só imagem PNG do folheto.
  leaflet,

  /// Imagem + link no mesmo share sheet.
  linkWithLeaflet,

  /// Folheto e link em dois shares guiados (WhatsApp).
  linkAndLeafletWhatsApp,
}

/// Dados mínimos para compartilhar playlist — carousel ou tile salvo.
class PlaylistShareContext {
  const PlaylistShareContext({
    required this.playlistId,
    required this.nome,
    required this.pdfIds,
    this.fromCarousel = false,
  });

  final String playlistId;
  final String nome;

  /// IDs na ordem da lista ou do carousel.
  final List<String> pdfIds;

  /// `true` quando [pdfIds] reflete a seleção do carousel; `false` para playlist salva.
  final bool fromCarousel;
}
