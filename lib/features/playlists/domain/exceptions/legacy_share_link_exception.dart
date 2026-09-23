/// Link de lista de uma versão antiga (`?s=`, `sharepdfs`, `shareitems`,
/// `shareaudios`, `sharename` — spec fim-fonte-plpcg §4.4): não abre mais.
///
/// Lançada por `ImportSharedPlaylistFromUrl`; a UI mostra
/// `playlistShareLegacyLinkUnsupported`.
class LegacyShareLinkException implements Exception {
  const LegacyShareLinkException();

  @override
  String toString() => 'LegacyShareLinkException';
}
