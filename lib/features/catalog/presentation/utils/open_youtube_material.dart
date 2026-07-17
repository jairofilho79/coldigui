import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/coldigom/domain/utils/youtube_url.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre o YouTube externo (app via Universal/App Links; senão navegador).
///
/// Na web abre em nova aba (`_blank`).
/// Retorna `false` se a URL for inválida ou o launch falhar.
Future<bool> openYoutubeMaterial(YoutubeMaterial material) async {
  final uri = YoutubeUrl.tryParse(material.url);
  if (uri == null) return false;

  try {
    return await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: kIsWeb ? '_blank' : null,
    );
  } on Object {
    return false;
  }
}
