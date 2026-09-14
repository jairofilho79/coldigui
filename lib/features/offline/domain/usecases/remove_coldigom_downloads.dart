import '../../../../core/utils/pdf_id_codec.dart';
import '../repositories/offline_audio_repository.dart';
import '../repositories/offline_pdf_repository.dart';

class RemoveColdigomDownloadsResult {
  const RemoveColdigomDownloadsResult({
    required this.removedPdfs,
    required this.removedAudios,
  });

  final int removedPdfs;

  /// Áudios no índice antes de apagar tudo.
  final int removedAudios;
}

/// «Remover áudios e PDFs baixados do Coldigom» (spec §5.2, O8).
///
/// Áudio sai inteiro (índice + store — só entra lá por download explícito).
/// PDF Coldigom só o persistente: o LRU on-demand continua a ser cache do
/// leitor e o PLPCG não é tocado. Cifras e gestos ficam — pesam KB e não são
/// evictados («textos ficam sempre» na UI).
class RemoveColdigomDownloads {
  const RemoveColdigomDownloads({
    required OfflinePdfRepository pdfRepository,
    required OfflineAudioRepository audioRepository,
  }) : _pdfRepository = pdfRepository, // ignore: prefer_initializing_formals
       // ignore: prefer_initializing_formals
       _audioRepository = audioRepository;

  final OfflinePdfRepository _pdfRepository;
  final OfflineAudioRepository _audioRepository;

  Future<RemoveColdigomDownloadsResult> call() async {
    final audios = (await _audioRepository.listAll()).length;
    await _audioRepository.removeAll();

    var removedPdfs = 0;
    for (final entry in await _pdfRepository.listAll()) {
      if (!entry.isPersistent || !isColdigomPdfId(entry.pdfId)) continue;
      await _pdfRepository.remove(entry.pdfId);
      removedPdfs++;
    }
    return RemoveColdigomDownloadsResult(
      removedPdfs: removedPdfs,
      removedAudios: audios,
    );
  }
}
