import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../catalog/presentation/providers/louvores_manifest_provider.dart';
import '../../../../deferred/leaflet_deferred.dart' deferred as leaflet;
import '../../data/providers/playlist_providers.dart';
import '../../domain/entities/playlist_share_option.dart';
import '../../domain/exceptions/empty_carousel_exception.dart';
import '../../domain/exceptions/empty_playlist_share_exception.dart';
import '../../domain/exceptions/playlist_not_found_exception.dart';
import '../providers/playlists_provider.dart';
import '../utils/playlist_share_debug_log.dart';
import '../widgets/playlist_share_whatsapp_step_dialog.dart';

/// Callback injetável para testes — espelha [leaflet.captureLeafletPngBytes].
typedef CaptureWidgetToPngFn =
    Future<List<int>> Function(GlobalKey boundaryKey);

/// Callback injetável para testes — espelha `Share.shareXFiles`.
typedef ShareXFilesFn =
    Future<void> Function(
      List<XFile> files, {
      String? subject,
      String? text,
      Rect? sharePositionOrigin,
    });

/// Orquestra os 4 modos de compartilhamento (UC-07/UC-08).
class PlaylistShareActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Executa [option] para [shareContext].
  ///
  /// [sharePositionOrigin] deve ser capturado antes de qualquer `await`.
  /// Retorna `false` em falha ou cancelamento antes do segundo passo WhatsApp.
  Future<bool> share(
    BuildContext context,
    PlaylistShareContext shareContext,
    PlaylistShareOption option, {
    required Rect? sharePositionOrigin,
    ShareFn? share,
    ShareXFilesFn? shareXFiles,
    CaptureWidgetToPngFn? capture,
    Future<bool> Function(BuildContext context)? showWhatsAppStepDialog,
  }) async {
    playlistShareDebugClearLastFailure();
    final l10n = AppLocalizations.of(context)!;
    final shareTextFn = share ?? _defaultShare;
    final shareFilesFn = shareXFiles ?? _defaultShareXFiles;
    final whatsAppDialogFn =
        showWhatsAppStepDialog ?? showPlaylistShareWhatsAppStepDialog;

    try {
      switch (option) {
        case PlaylistShareOption.link:
          return _shareLinkOnly(shareContext, shareTextFn, sharePositionOrigin);
        case PlaylistShareOption.leaflet:
          return _shareLeafletOnly(
            context,
            shareContext,
            l10n,
            shareFilesFn,
            sharePositionOrigin,
            capture: capture,
          );
        case PlaylistShareOption.linkWithLeaflet:
          return _shareLinkWithLeaflet(
            context,
            shareContext,
            l10n,
            shareFilesFn,
            sharePositionOrigin,
            capture: capture,
          );
        case PlaylistShareOption.linkAndLeafletWhatsApp:
          return _shareWhatsAppTwoStep(
            context,
            shareContext,
            l10n,
            shareTextFn,
            shareFilesFn,
            sharePositionOrigin,
            whatsAppDialogFn,
            capture: capture,
          );
      }
    } on EmptyCarouselException catch (error, stackTrace) {
      playlistShareDebugLogError('seleção vazia', error, stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.playlistEmptyCarousel)));
      }
      return false;
    } on PlaylistNotFoundException catch (error, stackTrace) {
      playlistShareDebugLogError('playlist não encontrada', error, stackTrace);
      return false;
    } on EmptyPlaylistShareException catch (error, stackTrace) {
      playlistShareDebugLogError('playlist sem pdfIds', error, stackTrace);
      return false;
    } on Object catch (error, stackTrace) {
      playlistShareDebugLogError('share', error, stackTrace);
      if (context.mounted) {
        showPlaylistShareErrorSnackbar(context, l10n);
      }
      return false;
    }
  }

  Future<bool> _shareLinkOnly(
    PlaylistShareContext shareContext,
    ShareFn shareTextFn,
    Rect? sharePositionOrigin,
  ) async {
    final url = await _generateUrl(shareContext.playlistId);
    await shareTextFn(
      url,
      subject: shareContext.nome,
      sharePositionOrigin: sharePositionOrigin,
    );
    return true;
  }

  Future<bool> _shareLeafletOnly(
    BuildContext context,
    PlaylistShareContext shareContext,
    AppLocalizations l10n,
    ShareXFilesFn shareFilesFn,
    Rect? sharePositionOrigin, {
    CaptureWidgetToPngFn? capture,
  }) async {
    if (!context.mounted) return false;
    final overlay = Overlay.of(context);
    final xFile = await _captureLeafletXFile(
      overlay,
      shareContext,
      l10n,
      capture: capture,
    );
    if (!context.mounted) return false;

    await shareFilesFn(
      [xFile],
      subject: l10n.leafletShareSubject,
      sharePositionOrigin: sharePositionOrigin,
    );
    return true;
  }

  Future<bool> _shareLinkWithLeaflet(
    BuildContext context,
    PlaylistShareContext shareContext,
    AppLocalizations l10n,
    ShareXFilesFn shareFilesFn,
    Rect? sharePositionOrigin, {
    CaptureWidgetToPngFn? capture,
  }) async {
    final url = await _generateUrl(shareContext.playlistId);
    if (!context.mounted) return false;
    final overlay = Overlay.of(context);

    final xFile = await _captureLeafletXFile(
      overlay,
      shareContext,
      l10n,
      capture: capture,
    );
    if (!context.mounted) return false;

    final message = l10n.playlistShareLinkWithLeafletMessage(
      shareContext.nome,
      url,
    );
    await shareFilesFn(
      [xFile],
      subject: shareContext.nome,
      text: message,
      sharePositionOrigin: sharePositionOrigin,
    );
    return true;
  }

  Future<bool> _shareWhatsAppTwoStep(
    BuildContext context,
    PlaylistShareContext shareContext,
    AppLocalizations l10n,
    ShareFn shareTextFn,
    ShareXFilesFn shareFilesFn,
    Rect? sharePositionOrigin,
    Future<bool> Function(BuildContext context) whatsAppDialogFn, {
    CaptureWidgetToPngFn? capture,
  }) async {
    if (!context.mounted) return false;
    final overlay = Overlay.of(context);
    final xFile = await _captureLeafletXFile(
      overlay,
      shareContext,
      l10n,
      capture: capture,
    );
    if (!context.mounted) return false;

    await shareFilesFn(
      [xFile],
      subject: l10n.leafletShareSubject,
      sharePositionOrigin: sharePositionOrigin,
    );
    if (!context.mounted) return false;

    final continueShare = await whatsAppDialogFn(context);
    if (!continueShare || !context.mounted) return false;

    final url = await _generateUrl(shareContext.playlistId);
    if (!context.mounted) return false;

    await shareTextFn(
      url,
      subject: shareContext.nome,
      sharePositionOrigin: sharePositionOrigin,
    );
    return true;
  }

  Future<String> _generateUrl(String playlistId) {
    return ref.read(generatePlaylistShareUrlProvider)(playlistId: playlistId);
  }

  Future<XFile> _captureLeafletXFile(
    OverlayState overlay,
    PlaylistShareContext shareContext,
    AppLocalizations l10n, {
    CaptureWidgetToPngFn? capture,
  }) async {
    await leaflet.loadLibrary();
    final metadata = leaflet.buildLouvorMetadataMap(
      ref.read(louvoresManifestProvider).value?.louvores,
    );
    final document = await leaflet.resolveLeafletDocument(
      ref,
      pdfIds: shareContext.pdfIds,
      fromCarousel: shareContext.fromCarousel,
      metadata: metadata,
    );
    final labels = leaflet.LeafletContentLabels.fromL10n(
      l10n,
      document.generatedAt,
    );
    leaflet.leafletDebugLog(
      'captureLeaflet: ${document.entries.length} entradas '
      '(fromCarousel=${shareContext.fromCarousel})',
    );
    final pngBytes = await leaflet.captureLeafletPngBytes(
      overlay,
      document,
      labels,
      capture: capture,
    );
    return leaflet.leafletXFileFromBytes(pngBytes);
  }
}

Future<void> _defaultShare(
  String text, {
  String? subject,
  Rect? sharePositionOrigin,
}) {
  return SharePlus.instance.share(
    ShareParams(
      text: text,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
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

final playlistShareActionsProvider =
    NotifierProvider<PlaylistShareActionsNotifier, void>(
      PlaylistShareActionsNotifier.new,
    );
