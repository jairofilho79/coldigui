import 'pdf_path_normalizer.dart';

/// Tipo de material que um id (`pdfId`) representa.
///
/// Cifra e PDF compartilham o mesmo espaço de ids — Base64 URL-safe do path
/// relativo do asset — para que carousel e playlist não precisem de um segundo
/// espaço de ids. O tipo é recuperado decodificando o id e olhando a extensão.
enum MaterialIdKind { pdf, chord, unknown }

/// Classifica [id] pela extensão do path que ele codifica.
///
/// Retorna [MaterialIdKind.unknown] para id inválido — nunca lança.
MaterialIdKind materialIdKindOf(String id) {
  if (id.isEmpty) return MaterialIdKind.unknown;

  final String relPath;
  try {
    relPath = PdfPathNormalizer.getPdfRelPath(id);
  } on Object {
    return MaterialIdKind.unknown;
  }

  final lower = relPath.toLowerCase();
  if (lower.endsWith('.pdf')) return MaterialIdKind.pdf;
  if (lower.endsWith('.chord')) return MaterialIdKind.chord;
  return MaterialIdKind.unknown;
}
