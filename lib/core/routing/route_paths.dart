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

  /// Offline UC-09/10 ([OfflineSettingsScreen]).
  static const String offline = '/offline';

  /// Playlists UC-06/07 ([PlaylistsScreen]).
  static const String playlists = '/listas';

  /// Sobre UC-14 ([AboutScreen]) — índice 0 em [PlpcgBottomNavBar].
  static const String about = '/sobre';
}
