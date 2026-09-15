/// Rotas do app (espelha SvelteKit routes).
///
/// Consumidores: [appRouterProvider], [ShellScaffold], [PlpcgBottomNavBar].
abstract final class RoutePaths {
  /// Home — pesquisa UC-01/02 ([HomeScreen]).
  static const String home = '/';

  /// Biblioteca paginada UC-03 ([LibraryScreen]) — branch Perfil.
  static const String library = '/biblioteca';

  /// Leitor PDF UC-11 — filha do [ShellRoute] com `parentNavigatorKey` fullscreen.
  static const String reader = '/leitor';

  /// Leitor de cifras ChordPro — irmã de [reader], filha da branch Home.
  static const String chords = '/cifra';

  /// Leitor de gestos CIAs — irmã de [chords], filha da branch Home.
  static const String gestos = '/gestos';

  /// Reprodutor de áudio Coldigom — filha da branch Home (mesmo shell/carousel).
  static const String audio = '/audio';

  /// Eventos — placeholder, primeira aba quando `FF_EVENTS` está ligada.
  static const String events = '/eventos';

  /// Rota antiga da aba Social — só existe para o `redirect` do router
  /// mandar links antigos para [publicPlaylists]. Nenhuma rota é registrada.
  static const String social = '/social';

  /// Perfil — hub Biblioteca/Offline/Sobre (última aba).
  static const String profile = '/perfil';

  /// Offline UC-09/10 ([OfflineSettingsScreen]) — branch Perfil.
  static const String offline = '/offline';

  /// Playlists UC-06/07 ([PlaylistsScreen]) — raiz da aba Listas.
  static const String playlists = '/listas';

  /// Listas públicas ([PublicPlaylistsScreen]) — sub-rota de [playlists],
  /// registrada só com `FF_SOCIAL`.
  static const String publicPlaylists = '/listas/publicas';

  /// Sobre UC-14 ([AboutScreen]) — branch Perfil.
  static const String about = '/sobre';

  /// Material kinds favoritos ([FavoriteMaterialKindsScreen]) — branch Perfil.
  static const String favoriteMaterialKinds = '/materiais-favoritos';

  /// Sala ao vivo ([LiveRoomScreen]) — filha da branch Home; o Worker manda
  /// `plpcg.com/ao-vivo/<code>` para `/?live=<code>` e o [DeepLinkListener]
  /// abre esta rota.
  static const String liveRoom = '/ao-vivo/:code';

  static String liveRoomFor(String code) => '/ao-vivo/$code';

  /// Leitor de letra Coldigom ([LyricsReaderScreen]) — irmã de [chords], branch Home.
  static const String lyrics = '/letra';
}
