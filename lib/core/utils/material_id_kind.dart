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
/// `audioId` com o mesmo `encodePdfId(r2Key)` dos PDFs/cifras, e é isso que
/// permite à playlist derivar `pdfIds`/`audioIds` de uma ordem única de ids.
///
/// **Atenção — a extensão aqui é uma heurística, não a fonte da verdade.** Quem
/// decide que um material é áudio é o campo `type` do Worker (`mp3`/`audio`,
/// ver `ColdigomLouvorAdapter._kindOfType`), que não olha o `r2_key`. Um áudio
/// publicado com extensão fora de [kAudioMaterialExtensions] (ou sem extensão)
/// classifica [MaterialKind.unknown] e cai na face de partituras. Mantenha a
/// lista abaixo em sincronia com o que o Worker aceita; a playlist avisa por
/// `debugPrint` quando recebe um id de áudio que não classifica
/// (`SavedPlaylist`).
///
/// YouTube não vive neste espaço (o id vem do Worker, não é um path): ele não
/// decodifica e portanto classifica [MaterialKind.unknown] — ou seja, **um id
/// de YouTube aparece em `pdfIds`**, junto com os ids legados e com
/// [MaterialKind.gesture] (documento JSON de gestos, `.gestures`, que abre em
/// `/gestos`). Nenhuma família fica invisível às duas faces da playlist (A7).
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
  if (lower.endsWith('.gestures')) return MaterialKind.gesture;
  final dot = lower.lastIndexOf('.');
  if (dot != -1 && kAudioMaterialExtensions.contains(lower.substring(dot))) {
    return MaterialKind.audio;
  }
  return MaterialKind.unknown;
}

/// Extensões que [materialIdKindOf] reconhece como [MaterialKind.audio].
///
/// Cobre o que um `type: mp3`/`audio` do Worker pode carregar no `r2_key`.
/// Ampliar aqui é seguro; esquecer uma extensão joga a faixa na face de
/// partituras.
const Set<String> kAudioMaterialExtensions = {
  '.mp3',
  '.m4a',
  '.m4b',
  '.aac',
  '.ogg',
  '.oga',
  '.opus',
  '.wav',
  '.flac',
  '.wma',
  '.weba',
  '.webm',
  '.aiff',
  '.aif',
};
