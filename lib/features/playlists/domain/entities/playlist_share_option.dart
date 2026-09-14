import 'playlist_entry.dart';

/// Modo de compartilhamento (UC-07/UC-08, spec short-id-share D9).
enum PlaylistShareOption {
  /// Só a URL da lista.
  link,

  /// Só a imagem PNG do folheto — usado pelo «Gerar folheto» do menu do tile
  /// (não aparece no sheet).
  leaflet,

  /// Folheto + link na mesma mensagem (imagem com legenda). Padrão do sheet.
  linkWithLeaflet,
}

/// Dados mínimos para compartilhar playlist — carousel ou tile salvo.
class PlaylistShareContext {
  const PlaylistShareContext({
    required this.playlistId,
    required this.nome,
    required this.entries,
    this.fromCarousel = false,
  });

  final String playlistId;
  final String nome;

  /// Entradas (tipadas) na ordem da lista ou do carousel — inclui áudio.
  final List<PlaylistEntry> entries;

  /// `true` quando [entries] reflete a seleção do carousel; `false` para playlist salva.
  final bool fromCarousel;
}
