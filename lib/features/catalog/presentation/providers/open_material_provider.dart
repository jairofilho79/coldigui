import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../audio_player/domain/entities/audio_track.dart';
import '../../../audio_player/presentation/utils/open_audio_in_player.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../../../chords/presentation/utils/open_chord_in_reader.dart';
import '../../../offline/domain/exceptions/pdf_resolve_exceptions.dart';
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

/// Toca uma faixa e abre `/audio` (`openAudioInPlayer` em produção).
typedef AudioMaterialOpener =
    Future<void> Function({
      required WidgetRef ref,
      required BuildContext context,
      required AudioTrack track,
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
  /// Falhas viram snackbar por [presentMaterialOpenError] — a escada de
  /// exceções de abertura vive num lugar só.
  Future<void> open(
    BuildContext context,
    WidgetRef ref,
    CatalogMaterial material,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      switch (material) {
        case PdfMaterial(:final louvor):
          await openPdf(ref: ref, context: context, louvor: louvor);
        case ChordMaterialRef(:final chord):
          await openChord(ref: ref, context: context, chord: chord);
        case AudioMaterial(:final track):
          await openAudio(ref: ref, context: context, track: track);
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
    PdfExternallyDeletedException(:final message) => MaterialOpenFailure(
      stage: 'PDF removido externamente',
      message: message,
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
/// Erros com mensagem própria (offline, apagado, download) mostram a mensagem;
/// o resto cai no genérico [AppLocalizations.pdfActionError].
void presentMaterialOpenError(
  BuildContext context,
  AppLocalizations? l10n,
  Object error,
) {
  if (!context.mounted) return;
  final failure = classifyMaterialOpenFailure(error);
  showAppSnackbar(
    context,
    failure.message ??
        l10n?.pdfActionError ??
        'Não foi possível concluir a ação',
  );
}
