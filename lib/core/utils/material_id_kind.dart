import 'pdf_path_normalizer.dart';

/// Vocabulário único de tipo de material do app.
///
/// Substitui o antigo `MaterialIdKind` (pdf/chord/unknown) e o enum privado do
/// sheet Coldigom: catálogo, carousel, playlist, adapter Coldigom e ícones
/// falam todos deste enum.
enum MaterialKind { pdf, chord, audio, youtube, gesture, unknown }

/// Classifica [id] pela extensão do path que ele codifica.
///
/// Cifra e PDF compartilham o mesmo espaço de ids — Base64 URL-safe do path
/// relativo do asset — para que carousel e playlist não precisem de um segundo
/// espaço de ids. O tipo é recuperado decodificando o id e olhando a extensão.
///
/// Retorna [MaterialKind.unknown] para id inválido — nunca lança. Áudio e
/// YouTube não vivem neste espaço de ids: `.mp3` continua [MaterialKind.unknown]
/// aqui (o áudio é reconhecido pela entidade, não pela extensão).
MaterialKind materialIdKindOf(String id) {
  if (id.isEmpty) return MaterialKind.unknown;

  final String relPath;
  try {
    relPath = PdfPathNormalizer.getPdfRelPath(id);
  } on Object {
    return MaterialKind.unknown;
  }

  final lower = relPath.toLowerCase();
  if (lower.endsWith('.pdf')) return MaterialKind.pdf;
  if (lower.endsWith('.chord')) return MaterialKind.chord;
  if (lower.endsWith('.txt') || lower.endsWith('.gest')) {
    return MaterialKind.gesture;
  }
  return MaterialKind.unknown;
}
