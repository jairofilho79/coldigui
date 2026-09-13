/// Link de share já montado (spec short-id-share §4.5).
///
/// [isShort] diz se saiu no formato curto `?s=…&n=…` — quem imprime o QR no
/// folheto decide por ele (D10) sem re-parsear [url].
class PlaylistShareLink {
  const PlaylistShareLink({required this.url, required this.isShort});

  final String url;
  final bool isShort;
}
