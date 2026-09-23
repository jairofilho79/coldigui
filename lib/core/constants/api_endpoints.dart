/// Endpoints HTTP do Worker `plpcg-catalog` (auth, social, playlists, flags,
/// links, live). Catálogo e assets vivem em `ColdigomEndpoints`.
abstract final class ApiEndpoints {
  /// Sessão Google — Worker `plpcg-catalog` + D1 `users`.
  ///
  /// `POST` + `Authorization: Bearer <id_token>` → perfil (`googleSub`, …).
  static const String authSession = '/api/auth/session';

  /// Define username único — `PUT` + Bearer + `{ username }`.
  static const String authUsername = '/api/auth/username';

  /// Busca social de usuários com listas públicas — `GET ?q=`.
  static const String socialUsers = '/api/social/users';

  static String socialUserPlaylists(String username) =>
      '/api/social/users/${Uri.encodeComponent(username)}/playlists';

  /// Playlists do usuário autenticado — Worker + D1 `user_playlists`.
  static const String playlists = '/api/playlists';

  static String playlist(String id) =>
      '/api/playlists/${Uri.encodeComponent(id)}';

  /// Marcadores de áudio do usuário — Worker + D1 `user_audio_flags`.
  static const String audioFlags = '/api/audio-flags';

  static String audioFlag(String id) =>
      '/api/audio-flags/${Uri.encodeComponent(id)}';

  /// Material kinds favoritos do usuário — Worker + D1
  /// `user_material_kind_prefs`. `GET` (`204` se nunca salvou) e `PUT`
  /// (`409` devolve o documento remoto mais novo).
  static const String materialKindPrefs = '/api/material-kind-prefs';

  /// Sala «ao vivo» do usuário — Worker + D1 `live_rooms` + DO `LiveRoom`.
  ///
  /// `POST` + Bearer → `{ code, url, ownerName }` (cria ou devolve).
  static const String liveRoom = '/api/live/room';

  /// `POST` + Bearer → novo código; o link antigo morre.
  static const String liveRoomRegenerate = '/api/live/room/regenerate';
}
