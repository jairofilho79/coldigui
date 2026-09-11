import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/share_position_origin.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../../../playlists/domain/entities/playlist_entry.dart';
import '../../../playlists/presentation/providers/active_playlist_editor.dart';
import '../../data/providers/leaflet_providers.dart';
import '../../domain/entities/leaflet_document.dart';
import '../../domain/exceptions/empty_leaflet_exception.dart';
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
  /// Retorna `false` se seleção vazia ([EmptyLeafletException] → snackbar
  /// `playlistEmptyCarousel`) ou falha na captura/share (`leafletGenerateFailed`).
  Future<bool> generateAndShare(
    BuildContext context, {
    ShareXFilesFn? shareXFiles,
    CaptureWidgetToPngFn? capture,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final shareOrigin = sharePositionOriginFromContextOrFallback(context);
    final shareFn = shareXFiles ?? _defaultShareXFiles;

    try {
      leafletDebugLog('generateAndShare: início');
      final entries = ref
          .read(activeEntriesProvider)
          .map((activeEntry) => activeEntry.entry)
          .toList(growable: false);
      final document = await resolveLeafletDocument(
        ref,
        entries: entries,
        fromCarousel: true,
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

      await shareFn(
        [leafletXFileFromBytes(pngBytes)],
        subject: l10n.leafletShareSubject,
        sharePositionOrigin: shareOrigin,
      );
      return true;
    } on EmptyLeafletException catch (error, stackTrace) {
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

/// Rótulos do folheto pelo [lookup] — cifra antes de PDF, áudio por último,
/// como nos chips.
///
/// O folheto (domain) não conhece o lookup (presentation); esta é a ponte.
LeafletLabelOf leafletLabelOf(CatalogMaterialLookup lookup) {
  return (materialId) {
    final chord = lookup.chord(materialId);
    if (chord != null) return (numero: chord.numero, nome: chord.nome);
    final louvor = lookup.louvor(materialId);
    if (louvor != null) return (numero: louvor.numero, nome: louvor.nome);
    final audioTrack = lookup.audioTrack(materialId);
    if (audioTrack != null) {
      return (numero: audioTrack.numero, nome: audioTrack.nome);
    }
    return null;
  };
}

/// Resolve [LeafletDocument] para [entries] — playlist salva ou seleção ativa
/// ([fromCarousel]), já unificadas por quem chama (D8: inclui áudio).
Future<LeafletDocument> resolveLeafletDocument(
  Ref ref, {
  required List<PlaylistEntry> entries,
  required bool fromCarousel,
}) async {
  return ref.read(generateLeafletFromEntriesProvider)(
    entries: entries,
    now: DateTime.now(),
  );
}

/// Captura folheto como [XFile] PNG (D4 OA).
Future<XFile> captureLeafletXFile(
  BuildContext context,
  LeafletDocument document,
  LeafletContentLabels labels, {
  CaptureWidgetToPngFn? capture,
}) async {
  final overlay = Overlay.of(context);
  final pngBytes = await captureLeafletPngBytes(
    overlay,
    document,
    labels,
    capture: capture,
  );
  return leafletXFileFromBytes(pngBytes);
}

/// Estado de ações do folheto — legado [generateAndShare] para testes diretos.
final leafletActionsProvider = NotifierProvider<LeafletActionsNotifier, void>(
  LeafletActionsNotifier.new,
);
