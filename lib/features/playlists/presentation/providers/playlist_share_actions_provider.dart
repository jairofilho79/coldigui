import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../../leaflet/domain/exceptions/empty_leaflet_exception.dart';
import '../../../leaflet/presentation/providers/leaflet_actions_provider.dart';
import '../../../leaflet/presentation/utils/leaflet_capture.dart';
import '../../../leaflet/presentation/utils/leaflet_debug_log.dart';
import '../../../leaflet/presentation/widgets/leaflet_content_labels.dart';
import '../../data/providers/playlist_providers.dart';
import '../../domain/entities/playlist_share_option.dart';
import '../../domain/exceptions/empty_playlist_share_exception.dart';
import '../../domain/exceptions/playlist_not_found_exception.dart';
import '../../domain/exceptions/praise_short_id_unavailable_exception.dart';
import '../providers/playlists_provider.dart';
import '../utils/playlist_share_debug_log.dart';

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
/// O link é sempre por praise (`?p=…&n=…`, spec fim-fonte-plpcg §4) e serve
/// a qualquer lista, com qualquer material. Entrada cujo praise não tem
/// `shortId` no catálogo local falha o share com o snackbar de erro e pede um
/// sync do catálogo (§4.2).
class PlaylistShareActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Executa [option] para [shareContext].
  ///
  /// [sharePositionOrigin] deve ser capturado antes de qualquer `await`.
  /// Retorna `false` em falha — o próprio provider mostra o snackbar
  /// (mensagem específica para [EmptyLeafletException], genérica para as
  /// demais exceções) antes de retornar; quem chama **não deve** mostrar
  /// outro snackbar em cima do retorno `false`. Em sucesso com entradas
  /// legadas fora do link, mostra `playlistShareSkippedEntries`.
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

    // Entradas legadas que o link gerado deixou de fora — o share segue e,
    // no fim, um snackbar avisa quantas.
    var skipped = 0;
    Future<String> generateUrl() async {
      final link = await ref
          .read(generatePlaylistShareUrlProvider)
          .generate(playlistId: shareContext.playlistId);
      skipped = link.skippedCount;
      return link.url;
    }

    try {
      final bool shared;
      switch (option) {
        case PlaylistShareOption.link:
          shared = await _shareLinkOnly(
            shareContext,
            shareTextFn,
            sharePositionOrigin,
            generateUrl,
          );
        case PlaylistShareOption.leaflet:
          shared = await _shareLeafletOnly(
            context,
            shareContext,
            l10n,
            shareFilesFn,
            sharePositionOrigin,
            generateUrl,
            capture: capture,
          );
        case PlaylistShareOption.linkWithLeaflet:
          shared = await _shareLinkWithLeaflet(
            context,
            shareContext,
            l10n,
            shareFilesFn,
            sharePositionOrigin,
            generateUrl,
            capture: capture,
          );
      }
      if (shared && skipped > 0 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.playlistShareSkippedEntries(skipped))),
        );
      }
      return shared;
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
      playlistShareDebugLogError('playlist sem entradas', error, stackTrace);
      if (context.mounted) {
        showPlaylistShareErrorSnackbar(context, l10n);
      }
      return false;
    } on PraiseShortIdUnavailableException catch (error, stackTrace) {
      playlistShareDebugLogError('praise sem shortId', error, stackTrace);
      _requestCatalogSync();
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
    PlaylistShareContext shareContext,
    ShareFn shareTextFn,
    Rect? sharePositionOrigin,
    Future<String> Function() generateUrl,
  ) async {
    final url = await generateUrl();
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
    Rect? sharePositionOrigin,
    Future<String> Function() generateUrl, {
    CaptureWidgetToPngFn? capture,
  }) async {
    // O folheto sai com o QR do link (§4.5). Só fica sem QR quando não pode
    // haver link: lista fora do repositório (ex.: web sem Isar), sem
    // entradas ou só com ids legados fora do Coldigom. Praise sem `shortId`
    // não cai aqui — falha o share (§4.2).
    String? qrUrl;
    try {
      qrUrl = await generateUrl();
    } on PlaylistNotFoundException catch (error, stackTrace) {
      playlistShareDebugLogError('link para QR', error, stackTrace);
    } on EmptyPlaylistShareException catch (error, stackTrace) {
      playlistShareDebugLogError('link para QR', error, stackTrace);
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
    Rect? sharePositionOrigin,
    Future<String> Function() generateUrl, {
    CaptureWidgetToPngFn? capture,
  }) async {
    final url = await generateUrl();
    if (!context.mounted) return false;
    final overlay = Overlay.of(context);

    final xFile = await _captureLeafletXFile(
      overlay,
      shareContext,
      l10n,
      capture: capture,
      shareUrl: url,
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

  /// Pedido quando um praise da lista não tem `shortId` no catálogo local
  /// (§4.2). Não bloqueia o snackbar; falha vira log.
  void _requestCatalogSync() {
    final syncNotifier = ref.read(coldigomCatalogSyncProvider.notifier);
    unawaited(
      syncNotifier.sync().then<void>(
        (_) {},
        onError: (Object e) =>
            debugPrint('[UC-07 playlist-share] sync do catálogo falhou: $e'),
      ),
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
