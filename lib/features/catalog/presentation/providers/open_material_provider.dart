import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/user_message_for.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../audio_player/domain/entities/audio_track.dart';
import '../../../audio_player/presentation/utils/open_audio_in_player.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../../../chords/presentation/utils/open_chord_in_reader.dart';
import '../../../gestures/domain/entities/gesture_material.dart';
import '../../../gestures/presentation/utils/open_gesture_in_reader.dart';
import '../../../offline/domain/exceptions/pdf_resolve_exceptions.dart';
import '../../../offline/presentation/utils/pdf_offline_error_ui.dart';
import '../../../pdf_reader/domain/exceptions/invalid_pdf_path_exception.dart';
import '../../domain/entities/catalog_material.dart';
import '../../domain/entities/louvor.dart';
import '../../domain/entities/youtube_material.dart';
import '../utils/open_louvor_in_reader.dart';
import '../utils/open_youtube_material.dart';

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

/// Abre um documento de gestos em `/gestos` (`openGestureInReader` em produção).
typedef GestureMaterialOpener =
    Future<void> Function({
      required WidgetRef ref,
      required BuildContext context,
      required GestureMaterial gesture,
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
    this.openGesture = openGestureInReader,
    this.openAudio = openAudioInPlayer,
    this.openYoutube = openYoutubeMaterial,
  });

  final PdfMaterialOpener openPdf;
  final ChordMaterialOpener openChord;
  final GestureMaterialOpener openGesture;
  final AudioMaterialOpener openAudio;
  final YoutubeMaterialOpener openYoutube;

  /// Abre [material] pelo caminho do seu [CatalogMaterial.kind].
  ///
  /// [audioQueue] só vale para [AudioMaterial]: é a fila em que a faixa toca.
  /// Quem tem o grupo passa `group.audioTracks`; sem isso o player pararia no
  /// fim do arranjo tocado.
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
        case GestureMaterialRef(:final gesture):
          await openGesture(ref: ref, context: context, gesture: gesture);
        case AudioMaterial(:final track):
          await openAudio(
            ref: ref,
            context: context,
            track: track,
            queue: audioQueue,
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

/// Falha de abertura já classificada pela escada única.
///
/// [message] é a mensagem própria da exceção — `null` quando o erro não tem uma
/// e a tela deve mostrar o texto genérico. [stage] é o rótulo usado nos logs de
/// diagnóstico da playlist; [logWithStack] diz se o log deve levar o stack
/// trace (falhas de I/O) ou só o detalhe.
class MaterialOpenFailure {
  const MaterialOpenFailure({
    required this.stage,
    required this.message,
    required this.logWithStack,
  });

  final String stage;
  final String? message;
  final bool logWithStack;
}

/// Escada única de exceções de abertura de material.
///
/// Mesma ordem que vivia duplicada em `openCarouselPdfInReader` e em
/// `PlaylistListTile._openPdfInReader`. [genericStage] nomeia o caso final nos
/// logs de quem chama.
MaterialOpenFailure classifyMaterialOpenFailure(
  Object error, {
  String genericStage = 'abrir material',
}) {
  return switch (error) {
    InvalidPdfPathException() => const MaterialOpenFailure(
      stage: 'caminho PDF inválido',
      message: null,
      logWithStack: true,
    ),
    PdfOfflineUnavailableException(:final message) => MaterialOpenFailure(
      stage: 'PDF offline indisponível',
      message: message,
      logWithStack: false,
    ),
    // Sem `message`: as duas exceções abaixo não carregam mais literal PT, e o
    // texto sai de `userMessageFor` (chaves `pdfExternallyDeleted` /
    // `pdfLocalCorrupted`). O `stage` continua nomeando o caso nos logs.
    PdfExternallyDeletedException() => const MaterialOpenFailure(
      stage: 'PDF removido externamente',
      message: null,
      logWithStack: false,
    ),
    PdfLocalCorruptedException() => const MaterialOpenFailure(
      stage: 'PDF local corrompido',
      message: null,
      logWithStack: false,
    ),
    PdfFetchFailedException(:final message) => MaterialOpenFailure(
      stage: 'falha ao baixar PDF',
      message: message,
      logWithStack: true,
    ),
    _ => MaterialOpenFailure(
      stage: genericStage,
      message: null,
      logWithStack: true,
    ),
  };
}

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
