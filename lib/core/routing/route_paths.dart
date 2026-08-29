/// Rotas do app (espelha SvelteKit routes).
///
/// Consumidores: [appRouterProvider], [ShellScaffold], [PlpcgBottomNavBar].
abstract final class RoutePaths {
  /// Home — pesquisa UC-01/02 ([HomeScreen]).
  static const String home = '/';

  /// Biblioteca paginada UC-03 ([LibraryScreen]).
  static const String library = '/biblioteca';

  /// Leitor PDF UC-11 — filha do [ShellRoute] com `parentNavigatorKey` fullscreen.
  static const String reader = '/leitor';

  /// Reprodutor de áudio Coldigom — filha da branch Home (mesmo shell/carousel).
  static const String audio = '/audio';

  /// Leitor de cifras ChordPro — irmã de [reader], filha da branch Home.
  static const String chords = '/cifra';

  /// Eventos — oculto neste build (deep link → home).
  static const String events = '/eventos';

  /// Social — oculto neste build (deep link → home).
  static const String social = '/social';

  /// Perfil — oculto neste build (deep link → home).
  static const String profile = '/perfil';

  /// Offline UC-09/10 — oculto neste build (deep link → home).
  static const String offline = '/offline';

  /// Playlists UC-06/07 ([PlaylistsScreen]) — aba Listas (índice 2).
  static const String playlists = '/listas';

  /// Sobre UC-14 — oculto neste build (deep link → home).
  static const String about = '/sobre';
}
