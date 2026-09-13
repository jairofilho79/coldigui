import 'feature_flags.dart';

/// Abas do shell principal (UC-14), ordem fixa de exibição.
///
/// [events] só aparece quando [FeatureFlags.events] está ligada — ver
/// [appTabsFor]. [playlists], [home] e [profile] são sempre exibidas.
///
/// Biblioteca vive na branch Perfil e Listas públicas (a antiga aba Social)
/// é sub-rota de Listas — nenhuma das duas é aba.
enum AppTab { events, playlists, home, profile }

/// Abas visíveis para [flags], na ordem fixa de [AppTab].
///
/// Router (`appRouterProvider`) e shell (`ShellScaffold`) montam suas
/// `StatefulShellBranch`/destinations a partir desta mesma lista — os
/// índices de branch/aba são sempre a posição do item nesta lista, nunca um
/// valor fixo.
List<AppTab> appTabsFor(FeatureFlags flags) => [
  if (flags.events) AppTab.events,
  AppTab.playlists,
  AppTab.home,
  AppTab.profile,
];
