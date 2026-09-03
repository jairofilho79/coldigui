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
/// Áudio Coldigom também vive neste espaço: `ColdigomLouvorAdapter` monta
/// `audioId` com o mesmo `encodePdfId(r2Key)` dos PDFs/cifras, então a extensão
/// do R2 key (`.mp3`, `.m4a`, `.ogg`, `.wav`) classifica a faixa. Isso é o que
/// permite à playlist derivar `pdfIds`/`audioIds` de uma ordem única de ids.
/// YouTube não vive aqui (o id vem do worker, não é path) e cai em
/// [MaterialKind.unknown].
///
/// Retorna [MaterialKind.unknown] para id inválido — nunca lança.
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
  if (lower.endsWith('.mp3') ||
      lower.endsWith('.m4a') ||
      lower.endsWith('.ogg') ||
      lower.endsWith('.wav')) {
    return MaterialKind.audio;
  }
  return MaterialKind.unknown;
}
