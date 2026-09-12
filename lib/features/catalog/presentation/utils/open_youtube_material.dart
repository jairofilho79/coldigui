import 'package:coldigui/core/platform/platform_capabilities.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/coldigom/domain/utils/youtube_url.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre o YouTube externo (app via Universal/App Links; senão navegador).
///
/// Na web abre em nova aba (`_blank`).
/// Retorna `false` se a URL for inválida ou o launch falhar — quem chama avisa
/// o usuário (`openMaterialProvider` mostra `youtubeOpenError`).
///
/// [capabilities] vem de `platformCapabilitiesProvider` — quem chama é
/// `OpenMaterial.open()` (ref-bearing), não este utilitário (T2, Global
/// Constraint: `kIsWeb`/plataforma fora de `core`/`data` só via provider).
Future<bool> openYoutubeMaterial(
  YoutubeMaterial material, {
  required PlatformCapabilities capabilities,
}) async {
  final uri = YoutubeUrl.tryParse(material.url);
  if (uri == null) return false;

  try {
    return await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: capabilities.isWeb ? '_blank' : null,
    );
  } on Object catch (e) {
    debugPrint('[catalog] falha ao abrir YouTube: $e');
    return false;
  }
}
