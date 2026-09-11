import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/user_message_for.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../audio_player/domain/entities/audio_track.dart';
import '../../../audio_player/presentation/utils/active_list_audio_queue.dart';
import '../../../audio_player/presentation/utils/open_audio_in_player.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../../../chords/presentation/utils/open_chord_in_reader.dart';
import '../../../offline/domain/exceptions/pdf_resolve_exceptions.dart';
import '../../../offline/presentation/utils/pdf_offline_error_ui.dart';
import '../../domain/entities/catalog_material.dart';
import '../../domain/entities/louvor.dart';
import '../../domain/entities/youtube_material.dart';
import '../utils/open_louvor_in_reader.dart';
import '../utils/open_youtube_material.dart';
import 'material_open_failure.dart';

/// [classifyMaterialOpenFailure] mudou de arquivo para quebrar o ciclo de
/// imports (ver `material_open_failure.dart`); quem já importava daqui continua
/// enxergando a escada.
export 'material_open_failure.dart';

/// Abre um PDF no leitor interno (`openLouvorInReader` em produção).
typedef PdfMaterialOpener =
    Future<void> Function({
      required WidgetRef ref,
      required BuildContext context,
      required Louvor louvor,
    });

/// Abre uma cifra em `/cifra` (`openChordInReader` em produção).
typedef ChordMaterialOpener =
    Future<void> Function({
      required WidgetRef ref,
      required BuildContext context,
      required ChordMaterial chord,
    });

/// Toca uma faixa e abre `/audio` (`openAudioInPlayer` em produção).
///
/// [queue] é a fila em que a faixa toca — quem tem o grupo (o sheet de
/// materiais) passa `group.audioTracks` para o playback não parar no fim do
/// primeiro arranjo. Sem fila, toca só a faixa.
typedef AudioMaterialOpener =
    Future<void> Function({
      required WidgetRef ref,
      required BuildContext context,
      required AudioTrack track,
      List<AudioTrack>? queue,
    });

/// Abre o YouTube externo; `false` quando a URL é inválida ou o launch falha.
typedef YoutubeMaterialOpener = Future<bool> Function(YoutubeMaterial material);

/// Ponto único de abertura de material do app.
///
/// O `switch` sobre [CatalogMaterial] é exaustivo por ser `sealed`: um material
/// novo quebra a compilação aqui em vez de cair num caminho silencioso. Cada
/// caso delega ao opener que já existia — nenhum comportamento muda, só deixa
/// de estar espalhado por cards, sheets, playlist e carousel.
///
/// Os openers são injetáveis para teste; em produção os padrões valem.
class OpenMaterial {
  const OpenMaterial({
    this.openPdf = openLouvorInReader,
    this.openChord = openChordInReader,
    this.openAudio = openAudioInPlayer,
    this.openYoutube = openYoutubeMaterial,
  });

  final PdfMaterialOpener openPdf;
  final ChordMaterialOpener openChord;
  final AudioMaterialOpener openAudio;
  final YoutubeMaterialOpener openYoutube;

  /// Abre [material] pelo caminho do seu [CatalogMaterial.kind].
  ///
  /// [audioQueue] só vale para [AudioMaterial]: é a fila em que a faixa toca.
  /// Quem tem o grupo passa `group.audioTracks`; sem isso a fila sai de
  /// [queueForTrack] sobre a lista ativa (D4) — faixa da reunião toca a
  /// reunião, faixa de fora toca sozinha.
  ///
  /// Falhas viram snackbar por [presentMaterialOpenError] — a escada de
  /// exceções de abertura vive num lugar só.
  Future<void> open(
    BuildContext context,
    WidgetRef ref,
    CatalogMaterial material, {
    List<AudioTrack>? audioQueue,
  }) async {
    final l10n = AppLocalizations.of(context);
    try {
      switch (material) {
        case PdfMaterial(:final louvor):
          await openPdf(ref: ref, context: context, louvor: louvor);
        case ChordMaterialRef(:final chord):
          await openChord(ref: ref, context: context, chord: chord);
        case AudioMaterial(:final track):
          await openAudio(
            ref: ref,
            context: context,
            track: track,
            // Sem fila do chamador, a reunião decide (D4): a faixa que já está
            // na lista ativa toca na lista inteira; a de fora toca sozinha,
            // como antes.
            queue:
                audioQueue ??
                queueForTrack(
                  track: track,
                  groupTracks: [track],
                  activeQueue: activeListAudioQueue(ref),
                ),
          );
        case YoutubeMaterialRef(:final material):
          final opened = await openYoutube(material);
          if (!opened && context.mounted) {
            showAppSnackbar(
              context,
              l10n?.youtubeOpenError ?? 'Não foi possível abrir o YouTube',
            );
          }
      }
    } on Object catch (error) {
      if (context.mounted) presentMaterialOpenError(context, l10n, error);
    }
  }
}

/// Ponto único de abertura de material (PDF, cifra, áudio, YouTube).
final openMaterialProvider = Provider<OpenMaterial>(
  (ref) => const OpenMaterial(),
);

/// Mostra a snackbar da falha [error] ao abrir material.
///
/// PDF que não está offline continua ganhando a snackbar **com ação** para a
/// tela offline ("Baixar"), como o card já fazia antes do sheet único — a
/// mensagem sem saída seria uma regressão de UX. Os demais erros com mensagem
/// própria (apagado, download) mostram a mensagem.
///
/// O resto passa por [userMessageFor]: abrir uma cifra ou um áudio estoura
/// `DioException`/`StorageUnavailableException`, que a escada de PDF não
/// classifica — mostrar o genérico ali escondia "sem conexão" e "sem
/// armazenamento", que o usuário sabe resolver. Só sem [l10n] resta o literal.
void presentMaterialOpenError(
  BuildContext context,
  AppLocalizations? l10n,
  Object error,
) {
  if (!context.mounted) return;
  if (error is PdfOfflineUnavailableException) {
    showPdfOfflineUnavailableSnackbar(context, message: error.message);
    return;
  }
  final failure = classifyMaterialOpenFailure(error);
  showAppSnackbar(
    context,
    failure.message ??
        (l10n != null
            ? userMessageFor(l10n, error)
            : 'Não foi possível concluir a ação'),
  );
}
