import 'feature_flags.dart';

/// Abas do shell principal (UC-14), ordem fixa de exibição.
///
/// [events] e [social] só aparecem quando a flag correspondente
/// ([FeatureFlags.events]/[FeatureFlags.social]) está ligada — ver
/// [appTabsFor]. [library], [home] e [profile] são sempre exibidas.
enum AppTab { events, library, home, social, profile }

/// Abas visíveis para [flags], na ordem fixa de [AppTab].
///
/// Router (`appRouterProvider`) e shell (`ShellScaffold`) montam suas
/// `StatefulShellBranch`/destinations a partir desta mesma lista — os
/// índices de branch/aba são sempre a posição do item nesta lista, nunca um
/// valor fixo.
List<AppTab> appTabsFor(FeatureFlags flags) => [
  if (flags.events) AppTab.events,
  AppTab.library,
  AppTab.home,
  if (flags.social) AppTab.social,
  AppTab.profile,
];
