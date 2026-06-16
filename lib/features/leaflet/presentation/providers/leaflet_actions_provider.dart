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
import '../utils/leaflet_debug_log.dart';
import '../utils/leaflet_image_capture.dart';
import '../widgets/leaflet_content.dart';
import '../widgets/leaflet_content_labels.dart';

/// Callback injetável para testes — espelha `Share.shareXFiles` do [share_plus].
typedef ShareXFilesFn = Future<void> Function(
  List<XFile> files, {
  String? subject,
  Rect? sharePositionOrigin,
});

/// Callback injetável para testes — espelha [path_provider.getTemporaryDirectory].
typedef GetTemporaryDirectoryFn = Future<Directory> Function();

/// Callback injetável para testes — espelha [captureWidgetToPng].
typedef CaptureWidgetToPngFn = Future<List<int>> Function(
  GlobalKey boundaryKey,
);

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
    // Obrigatório no iPad — capturar antes de qualquer await.
    final shareOrigin = sharePositionOriginFromContextOrFallback(context);
    final shareFn = shareXFiles ?? Share.shareXFiles;
    final tempDirFn =
        getTemporaryDirectory ?? path_provider.getTemporaryDirectory;
    final captureFn = capture ?? captureWidgetToPng;

    try {
      leafletDebugLog('generateAndShare: início');
      final metadata =
          _buildMetadataMap(ref.read(louvoresManifestProvider).value?.louvores);
      leafletDebugLog(
        'generateAndShare: manifest metadata=${metadata.length} itens',
      );
      final document = await ref.read(generateLeafletFromSelectionProvider)(
        pdfIdToMetadata: metadata,
      );
      final labels = LeafletContentLabels.fromL10n(l10n, document.generatedAt);
      leafletDebugLog(
        'generateAndShare: documento com ${document.entries.length} entradas',
      );

      if (!context.mounted) {
        leafletDebugLog('generateAndShare: context desmontado após documento');
        return false;
      }
      final overlay = Overlay.of(context);
      leafletDebugLog('generateAndShare: capturando PNG…');
      final pngBytes =
          await _captureDocument(overlay, document, labels, captureFn);
      leafletDebugLog(
          'generateAndShare: captura OK (${pngBytes.length} bytes)');

      final tempDir = await tempDirFn();
      final file = File('${tempDir.path}/folheto-plpcg.png');
      await file.writeAsBytes(pngBytes, flush: true);
      leafletDebugLog('generateAndShare: arquivo ${file.path}');

      leafletDebugLog(
        'generateAndShare: share sheet (origin=$shareOrigin, '
        'entries=${document.entries.length})…',
      );
      await shareFn(
        [
          XFile(
            file.path,
            mimeType: 'image/png',
            name: 'folheto-plpcg.png',
          ),
        ],
        subject: l10n.leafletShareSubject,
        sharePositionOrigin: shareOrigin,
      );
      leafletDebugLog('generateAndShare: concluído com sucesso');
      return true;
    } on EmptyCarouselException catch (error, stackTrace) {
      leafletDebugLogError('seleção vazia', error, stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.playlistEmptyCarousel)),
        );
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

  Map<String, CarouselItemMetadata> _buildMetadataMap(List<Louvor>? catalog) {
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

  Future<List<int>> _captureDocument(
    OverlayState overlay,
    LeafletDocument document,
    LeafletContentLabels labels,
    CaptureWidgetToPngFn captureFn,
  ) async {
    final boundaryKey = GlobalKey();
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        top: 0,
        child: IgnorePointer(
          child: Opacity(
            // 0.01 — opacity 0 pode pular pintura e quebrar toImage() no iOS.
            opacity: 0.01,
            child: RepaintBoundary(
              key: boundaryKey,
              child: LeafletContent(document: document, labels: labels),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      return await captureFn(boundaryKey);
    } finally {
      entry.remove();
    }
  }
}

/// Estado de ações do folheto — [generateAndShare] na barra [CarouselChips].
final leafletActionsProvider =
    NotifierProvider<LeafletActionsNotifier, void>(LeafletActionsNotifier.new);
