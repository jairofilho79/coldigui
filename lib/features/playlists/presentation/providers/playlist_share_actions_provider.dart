import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../leaflet/domain/exceptions/empty_leaflet_exception.dart';
import '../../../leaflet/presentation/providers/leaflet_actions_provider.dart';
import '../../../leaflet/presentation/utils/leaflet_capture.dart';
import '../../../leaflet/presentation/utils/leaflet_debug_log.dart';
import '../../../leaflet/presentation/widgets/leaflet_content_labels.dart';
import '../../data/providers/playlist_providers.dart';
import '../../domain/entities/playlist_share_link.dart';
import '../../domain/entities/playlist_share_option.dart';
import '../../domain/exceptions/empty_playlist_share_exception.dart';
import '../../domain/exceptions/playlist_not_found_exception.dart';
import '../providers/playlists_provider.dart';
import '../utils/playlist_share_debug_log.dart';
import '../widgets/coldigom_share_dialog.dart';

/// Callback injetável para testes — espelha [captureLeafletPngBytes].
typedef CaptureWidgetToPngFn = Future<List<int>> Function(
  GlobalKey boundaryKey,
);

/// Callback injetável para testes — espelha `Share.shareXFiles`.
typedef ShareXFilesFn = Future<void> Function(
  List<XFile> files, {
  String? subject,
  String? text,
  Rect? sharePositionOrigin,
});

/// Orquestra os 3 modos: link, folheto, folheto+link.
///
/// Gate Coldigom: lista que não é PLPCG pura (`!link.isShort`) não gera
/// link nem QR — só folheto, após confirmação em [showColdigomShareDialog].
class PlaylistShareActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Executa [option] para [shareContext].
  ///
  /// [sharePositionOrigin] deve ser capturado antes de qualquer `await`.
  /// Retorna `false` em falha — o próprio provider mostra o snackbar
  /// (mensagem específica para [EmptyLeafletException], genérica para as
  /// demais exceções) antes de retornar; quem chama **não deve** mostrar
  /// outro snackbar em cima do retorno `false`. Também retorna `false`,
  /// **sem** snackbar, quando o usuário cancela ou dispensa o
  /// [showColdigomShareDialog] (lista fora do acervo PLPCG).
  Future<bool> share(
    BuildContext context,
    PlaylistShareContext shareContext,
    PlaylistShareOption option, {
    required Rect? sharePositionOrigin,
    ShareFn? share,
    ShareXFilesFn? shareXFiles,
    CaptureWidgetToPngFn? capture,
  }) async {
    playlistShareDebugClearLastFailure();
    final l10n = AppLocalizations.of(context)!;
    final shareTextFn = share ?? _defaultShare;
    final shareFilesFn = shareXFiles ?? _defaultShareXFiles;

    try {
      switch (option) {
        case PlaylistShareOption.link:
          return await _shareLinkOnly(
            context,
            shareContext,
            shareTextFn,
            sharePositionOrigin,
          );
        case PlaylistShareOption.leaflet:
          return await _shareLeafletOnly(
            context,
            shareContext,
            l10n,
            shareFilesFn,
            sharePositionOrigin,
            capture: capture,
          );
        case PlaylistShareOption.linkWithLeaflet:
          return await _shareLinkWithLeaflet(
            context,
            shareContext,
            l10n,
            shareFilesFn,
            sharePositionOrigin,
            capture: capture,
          );
      }
    } on EmptyLeafletException catch (error, stackTrace) {
      playlistShareDebugLogError('seleção vazia', error, stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.playlistEmptyCarousel)));
      }
      return false;
    } on PlaylistNotFoundException catch (error, stackTrace) {
      playlistShareDebugLogError('playlist não encontrada', error, stackTrace);
      if (context.mounted) {
        showPlaylistShareErrorSnackbar(context, l10n);
      }
      return false;
    } on EmptyPlaylistShareException catch (error, stackTrace) {
      playlistShareDebugLogError('playlist sem pdfIds', error, stackTrace);
      if (context.mounted) {
        showPlaylistShareErrorSnackbar(context, l10n);
      }
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
    BuildContext context,
    PlaylistShareContext shareContext,
    ShareFn shareTextFn,
    Rect? sharePositionOrigin,
  ) async {
    final link = await _generateUrl(shareContext.playlistId);
    if (!link.isShort) {
      if (context.mounted) {
        await showColdigomShareDialog(context, offerLeafletOnly: false);
      }
      return false;
    }
    await shareTextFn(
      link.url,
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
    // QR só com link curto (D10). Lista sem registro/sem material no
    // repositório não impede o folheto: fica sem QR.
    String? qrUrl;
    try {
      // Formato do QR (curto/longo) decidido localmente — ver comentário de
      // `_generateUrl` sobre o `/l/` não ter mais chamador aqui.
      final link = await _generateUrl(shareContext.playlistId);
      if (link.isShort) qrUrl = link.url;
    } on Object catch (error, stackTrace) {
      playlistShareDebugLogError('link para QR', error, stackTrace);
      qrUrl = null;
    }
    if (!context.mounted) return false;
    final overlay = Overlay.of(context);
    final xFile = await _captureLeafletXFile(
      overlay,
      shareContext,
      l10n,
      capture: capture,
      shareUrl: qrUrl,
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
    final link = await _generateUrl(shareContext.playlistId);
    if (!context.mounted) return false;
    if (!link.isShort) {
      final leafletOnly = await showColdigomShareDialog(
        context,
        offerLeafletOnly: true,
      );
      if (!leafletOnly || !context.mounted) return false;
      return _shareLeafletOnly(
        context,
        shareContext,
        l10n,
        shareFilesFn,
        sharePositionOrigin,
        capture: capture,
      );
    }
    final overlay = Overlay.of(context);

    final xFile = await _captureLeafletXFile(
      overlay,
      shareContext,
      l10n,
      capture: capture,
      shareUrl: link.url,
    );
    if (!context.mounted) return false;

    final message = l10n.playlistShareLinkWithLeafletMessage(
      shareContext.nome,
      link.url,
    );
    await shareFilesFn(
      [xFile],
      subject: shareContext.nome,
      text: message,
      sharePositionOrigin: sharePositionOrigin,
    );
    return true;
  }

  Future<PlaylistShareLink> _generateUrl(String playlistId) {
    // Formato curto é decidido localmente por `PlaylistShareLink.isShort`;
    // o share não emite mais link longo, então o `/l/` não tem chamador
    // aqui (débito: remover junto com o gate Coldigom).
    return ref.read(generatePlaylistShareUrlProvider)(
      playlistId: playlistId,
      short: false,
    );
  }

  Future<XFile> _captureLeafletXFile(
    OverlayState overlay,
    PlaylistShareContext shareContext,
    AppLocalizations l10n, {
    CaptureWidgetToPngFn? capture,
    String? shareUrl,
  }) async {
    final document = await resolveLeafletDocument(
      ref,
      entries: shareContext.entries,
      fromCarousel: shareContext.fromCarousel,
      shareUrl: shareUrl,
    );
    final labels = LeafletContentLabels.fromL10n(l10n, document.generatedAt);
    leafletDebugLog(
      'captureLeaflet: ${document.entries.length} entradas '
      '(fromCarousel=${shareContext.fromCarousel})',
    );
    final pngBytes = await captureLeafletPngBytes(
      overlay,
      document,
      labels,
      capture: capture,
    );
    return leafletXFileFromBytes(pngBytes);
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
