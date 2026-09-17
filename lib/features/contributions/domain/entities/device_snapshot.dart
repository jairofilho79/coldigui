/// O que vai junto com um bug (spec §6.3). Nada aqui identifica a pessoa ou o
/// aparelho de forma única — é o suficiente para reproduzir, não para rastrear.
class DeviceSnapshot {
  const DeviceSnapshot({
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.locale,
    required this.screenW,
    required this.screenH,
    required this.pixelRatio,
    required this.online,
    required this.pwaStandalone,
    this.manufacturer,
    this.model,
    this.osVersion,
    this.userAgent,
  });

  final String appVersion;
  final String buildNumber;

  /// `android` | `ios` | `web` | `macos` | `windows` | `linux`.
  final String platform;
  final String locale;
  final int screenW;
  final int screenH;
  final double pixelRatio;
  final bool online;
  final bool pwaStandalone;
  final String? manufacturer;
  final String? model;
  final String? osVersion;
  final String? userAgent;

  String get versionLabel => '$appVersion+$buildNumber';

  Map<String, dynamic> toJson() => {
    'app_version': appVersion,
    'build_number': buildNumber,
    'platform': platform,
    'locale': locale,
    'screen_w': screenW,
    'screen_h': screenH,
    'pixel_ratio': pixelRatio,
    'online': online,
    'pwa_standalone': pwaStandalone,
    if (manufacturer != null) 'manufacturer': manufacturer,
    if (model != null) 'model': model,
    if (osVersion != null) 'os_version': osVersion,
    if (userAgent != null) 'user_agent': userAgent,
  };

  /// Linhas do cartão «Isto será enviado». Rótulos curtos e fixos (o cartão
  /// é técnico; não passa por l10n de propósito — o valor é o que importa).
  List<(String, String)> humanLines() => [
    ('App', versionLabel),
    ('Plataforma', platform),
    if (manufacturer != null || model != null)
      ('Dispositivo', [manufacturer, model].whereType<String>().join(' ')),
    if (osVersion != null) ('Sistema', osVersion!),
    if (userAgent != null) ('Navegador', userAgent!),
    ('Tela', '$screenW×$screenH @${pixelRatio}x'),
    ('Idioma', locale),
    ('Online', online ? 'sim' : 'não'),
    if (platform == 'web') ('PWA instalada', pwaStandalone ? 'sim' : 'não'),
  ];
}
