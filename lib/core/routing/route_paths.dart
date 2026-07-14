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

  /// Eventos — placeholder (índice 0 em [PlpcgBottomNavBar]).
  static const String events = '/eventos';

  /// Social — placeholder (índice 3 em [PlpcgBottomNavBar]).
  static const String social = '/social';

  /// Perfil — hub Sobre/Listas/Offline (índice 4 em [PlpcgBottomNavBar]).
  static const String profile = '/perfil';

  /// Offline UC-09/10 ([OfflineSettingsScreen]) — branch Perfil.
  static const String offline = '/offline';

  /// Playlists UC-06/07 ([PlaylistsScreen]) — branch Perfil.
  static const String playlists = '/listas';

  /// Sobre UC-14 ([AboutScreen]) — branch Perfil.
  static const String about = '/sobre';
}
