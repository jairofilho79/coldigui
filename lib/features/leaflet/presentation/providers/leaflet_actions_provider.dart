import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/share_position_origin.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../carousel/domain/entities/carousel_item.dart';
import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/presentation/providers/louvores_manifest_provider.dart';
import '../../../playlists/domain/exceptions/empty_carousel_exception.dart';
import '../../data/providers/leaflet_providers.dart';
import '../../domain/entities/leaflet_document.dart';
import '../utils/leaflet_capture.dart';
import '../utils/leaflet_debug_log.dart';
import '../widgets/leaflet_content_labels.dart';

/// Callback injetável para testes — espelha `Share.shareXFiles` do [share_plus].
typedef ShareXFilesFn =
    Future<void> Function(
      List<XFile> files, {
      String? subject,
      String? text,
      Rect? sharePositionOrigin,
    });

/// Orquestra geração e compartilhamento do folheto na UI (UC-08, Fase 4.6).
class LeafletActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Gera PNG da seleção atual e abre share sheet nativo.
  ///
  /// Retorna `false` se seleção vazia ([EmptyCarouselException] → snackbar
  /// `playlistEmptyCarousel`) ou falha na captura/share (`leafletGenerateFailed`).
  Future<bool> generateAndShare(
    BuildContext context, {
    ShareXFilesFn? shareXFiles,
    GetTemporaryDirectoryFn? getTemporaryDirectory,
    CaptureWidgetToPngFn? capture,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final shareOrigin = sharePositionOriginFromContextOrFallback(context);
    final shareFn = shareXFiles ?? _defaultShareXFiles;
    final tempDirFn =
        getTemporaryDirectory ?? path_provider.getTemporaryDirectory;

    try {
      leafletDebugLog('generateAndShare: início');
      final metadata = buildLouvorMetadataMap(
        ref.read(louvoresManifestProvider).value?.louvores,
      );
      final document = await ref.read(generateLeafletFromSelectionProvider)(
        pdfIdToMetadata: metadata,
      );
      final labels = LeafletContentLabels.fromL10n(l10n, document.generatedAt);

      if (!context.mounted) return false;
      final overlay = Overlay.of(context);
      final pngBytes = await captureLeafletPngBytes(
        overlay,
        document,
        labels,
        capture: capture,
      );
      final file = await writeLeafletPngToTempFile(
        pngBytes,
        getTemporaryDirectory: tempDirFn,
      );

      await shareFn(
        [leafletXFileFromFile(file)],
        subject: l10n.leafletShareSubject,
        sharePositionOrigin: shareOrigin,
      );
      return true;
    } on EmptyCarouselException catch (error, stackTrace) {
      leafletDebugLogError('seleção vazia', error, stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.playlistEmptyCarousel)));
      }
      return false;
    } on Object catch (error, stackTrace) {
      leafletDebugLogError('generateAndShare', error, stackTrace);
      if (context.mounted) {
        final message = kDebugMode
            ? '${l10n.leafletGenerateFailed}\n${leafletDebugErrorSummary(error)}'
            : l10n.leafletGenerateFailed;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: kDebugMode
                ? const Duration(seconds: 8)
                : const Duration(seconds: 4),
          ),
        );
      }
      return false;
    }
  }
}

Future<void> _defaultShareXFiles(
  List<XFile> files, {
  String? subject,
  String? text,
  Rect? sharePositionOrigin,
}) {
  return SharePlus.instance.share(
    ShareParams(
      files: files,
      subject: subject,
      text: text,
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
}

/// Mapa pdfId → metadados a partir do manifest (folheto UC-08).
Map<String, CarouselItemMetadata> buildLouvorMetadataMap(
  List<Louvor>? catalog,
) {
  if (catalog == null) return const {};
  return {
    for (final louvor in catalog)
      louvor.pdfId: CarouselItemMetadata(
        numero: louvor.numero,
        nome: louvor.nome,
        categoria: louvor.categoria,
        classificacao: louvor.classificacao,
      ),
  };
}

/// Resolve [LeafletDocument] para carousel ou playlist salva.
Future<LeafletDocument> resolveLeafletDocument(
  Ref ref, {
  required List<String> pdfIds,
  required bool fromCarousel,
  required Map<String, CarouselItemMetadata> metadata,
}) async {
  if (fromCarousel) {
    return ref.read(generateLeafletFromSelectionProvider)(
      pdfIdToMetadata: metadata,
    );
  }
  return ref.read(generateLeafletFromPdfIdsProvider)(
    pdfIds: pdfIds,
    pdfIdToMetadata: metadata,
  );
}

/// Captura folheto em arquivo temporário PNG.
Future<File> captureLeafletToTempFile(
  BuildContext context,
  LeafletDocument document,
  LeafletContentLabels labels, {
  CaptureWidgetToPngFn? capture,
  GetTemporaryDirectoryFn? getTemporaryDirectory,
}) async {
  final overlay = Overlay.of(context);
  final pngBytes = await captureLeafletPngBytes(
    overlay,
    document,
    labels,
    capture: capture,
  );
  return writeLeafletPngToTempFile(
    pngBytes,
    getTemporaryDirectory:
        getTemporaryDirectory ?? path_provider.getTemporaryDirectory,
  );
}

/// Estado de ações do folheto — legado [generateAndShare] para testes diretos.
final leafletActionsProvider = NotifierProvider<LeafletActionsNotifier, void>(
  LeafletActionsNotifier.new,
);
