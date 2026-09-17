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

  /// Linhas do cartão «Isto será enviado» — identificador + valor bruto (sem
  /// rótulo pronto: `DeviceSnapshot` é domínio puro, não sabe de l10n). Quem
  /// exibe (`DeviceConsentCard`) mapeia [DeviceLine] para o rótulo no idioma
  /// da pessoa; `online`/`pwa` mandam `'true'`/`'false'` (não `'sim'/'não'`
  /// — isso também é l10n) para quem exibe traduzir.
  List<(DeviceLine, String)> humanLines() => [
    (DeviceLine.app, versionLabel),
    (DeviceLine.platform, platform),
    if (manufacturer != null || model != null)
      (DeviceLine.device, [manufacturer, model].whereType<String>().join(' ')),
    if (osVersion != null) (DeviceLine.system, osVersion!),
    if (userAgent != null) (DeviceLine.browser, userAgent!),
    (DeviceLine.screen, '$screenW×$screenH @${pixelRatio}x'),
    (DeviceLine.locale, locale),
    (DeviceLine.online, online.toString()),
    if (platform == 'web') (DeviceLine.pwa, pwaStandalone.toString()),
  ];
}

/// Identificador de cada linha de [DeviceSnapshot.humanLines] — o rótulo em
/// si (l10n) é responsabilidade de quem exibe, não do domínio.
enum DeviceLine {
  app,
  platform,
  device,
  system,
  browser,
  screen,
  locale,
  online,
  pwa,
}
