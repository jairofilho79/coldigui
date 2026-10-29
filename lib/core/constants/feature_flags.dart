/// Feature flags do app, definidas em build time via `--dart-define`
/// (ver `dart_defines/*.json`).
///
/// [events]: aba «Eventos» (ainda placeholder — «Em breve»). `FF_EVENTS`,
/// padrão `false`.
/// [social]: Listas públicas (`/listas/publicas`, antiga aba Social) e o
/// botão que abre essa tela em Listas. `FF_SOCIAL`, padrão `true`.
/// [adminUpload]: UC-13, fora do MVP. `FF_ADMIN_UPLOAD`, padrão `false`.
///
/// Consumida via `featureFlagsProvider` (`core/providers/feature_flags_provider.dart`)
/// — nunca lida direto de `bool.fromEnvironment` fora de [fromEnvironment].
class FeatureFlags {
  const FeatureFlags({
    this.events = false,
    this.social = true,
    this.adminUpload = false,
  });

  /// Lê as três chaves de `--dart-define` do build atual.
  factory FeatureFlags.fromEnvironment() => const FeatureFlags(
    events: bool.fromEnvironment('FF_EVENTS'),
    social: bool.fromEnvironment('FF_SOCIAL', defaultValue: true),
    adminUpload: bool.fromEnvironment('FF_ADMIN_UPLOAD'),
  );

  final bool events;
  final bool social;
  final bool adminUpload;
}
