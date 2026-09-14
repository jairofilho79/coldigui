import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/storage_unavailable_exception.dart';
import '../../../../core/platform/platform_capabilities_provider.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/utils/home_url_builder.dart';
import '../../../../core/utils/playlist_share_url_builder.dart';
import '../../../../core/utils/safe_query_parameters.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../live/domain/live_room_link.dart';
import '../../../playlists/presentation/providers/playlists_provider.dart';
import '../../data/providers/app_shell_providers.dart';
import '../../domain/usecases/sync_deep_link_state.dart';
import '../utils/deep_link_initial_uri.dart';

/// Janela de dedupe do fingerprint de deep link (Tarefa 8, spec C.4).
const _dedupeWindow = Duration(seconds: 3);

/// UC-14 — Observa deep links e importa playlist compartilhada (Fase 4.5).
///
/// Montado em [ColdiguiApp] — subscription `app_links` (initial + stream),
/// dedupe por fingerprint, snackbar e navegação pós-import.
class DeepLinkListener extends ConsumerStatefulWidget {
  const DeepLinkListener({required this.child, super.key, this.now});

  final Widget child;

  /// Relógio injetável — exposto só para teste (dedupe de 3s, Tarefa 8).
  final DateTime Function()? now;

  @override
  ConsumerState<DeepLinkListener> createState() => DeepLinkListenerState();
}

class DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  StreamSubscription<Uri>? _linkSubscription;
  String? _lastProcessedKey;
  DateTime? _lastProcessedAt;
  var _handling = false;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribeToLinks());
  }

  Future<void> _subscribeToLinks() async {
    if (!ref.read(deepLinkHandlingEnabledProvider)) return;

    final appLinks = ref.read(appLinksProvider);
    Uri? initial;
    try {
      initial = await appLinks.getInitialLink();
    } on Object {
      // Plataforma sem suporte ou simulador — ignorar.
    }

    if (ref.read(platformCapabilitiesProvider).isWeb) {
      initial = resolveWebInitialDeepLinkUri(initial);
    }

    if (initial != null) {
      await _handleUri(initial);
    }

    _linkSubscription = appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handleUri(uri)),
      onError: (_) {},
    );
  }

  /// Processa URI de deep link — exposto para testes widget.
  @visibleForTesting
  Future<void> handleUriForTest(Uri uri) => _handleUri(uri);

  Future<void> _handleUri(Uri uri) async {
    if (_handling || !ref.read(deepLinkHandlingEnabledProvider)) return;

    // Sala ao vivo: sem import, só navegar (spec lista-ao-vivo D6).
    final liveCode = parseLiveRoomCode(uri);
    if (liveCode != null) {
      final fingerprint = 'live:$liveCode';
      if (_isRecentlyProcessed(fingerprint)) return;
      _markProcessed(fingerprint);
      ref.read(appRouterProvider).go(RoutePaths.liveRoomFor(liveCode));
      return;
    }

    final sanitizedUri = _sanitizeUri(uri);
    final params = parsePlaylistShareParams(sanitizedUri);
    if (params == null) return;

    final fingerprint = uri.query;
    if (_isRecentlyProcessed(fingerprint)) return;

    _handling = true;
    try {
      final result = await ref.read(syncDeepLinkStateProvider)(
        uri: sanitizedUri,
      );
      if (!mounted) return;

      switch (result.outcome) {
        case SyncDeepLinkOutcome.skipped:
          return;
        case SyncDeepLinkOutcome.success:
          _markProcessed(fingerprint);
          await ref.read(playlistsProvider.notifier).refreshAfterImport();
          if (!mounted) return;
          _navigateAfterImport(sanitizedUri);
          if (result.alreadyExisted) {
            _showSnackbar(
              (l10n) => l10n.playlistImportAlreadySaved(result.nome ?? ''),
            );
          } else {
            _showSnackbar((l10n) => l10n.playlistImported);
          }
        case SyncDeepLinkOutcome.invalid:
          _markProcessed(fingerprint);
          _navigateAfterImport(sanitizedUri);
          _showSnackbar((l10n) => l10n.playlistImportInvalidUrl);
        case SyncDeepLinkOutcome.failed:
          _markProcessed(fingerprint);
          _reportFailure(result.reason);
      }
      // Exceção também consome o link: sem `_markProcessed` o mesmo URI
      // reentraria a cada evento do stream, repetindo a snackbar de erro sem
      // nenhuma chance a mais de dar certo. Passada a janela de dedupe, o
      // usuário ainda pode abrir o link de novo.
    } on StorageUnavailableException catch (e) {
      _markProcessed(fingerprint);
      debugPrint('[deep-link] armazenamento indisponível: $e');
      _showSnackbar((l10n) => l10n.offlineStorageUnavailable);
    } on Object catch (e) {
      _markProcessed(fingerprint);
      debugPrint('[deep-link] falha ao importar: $e');
      _showSnackbar((l10n) => l10n.deepLinkImportFailed);
    } finally {
      _handling = false;
    }
  }

  /// Sanitiza [uri] contra `%` malformado antes de repassar ao parser de
  /// share params, que não tolera [FormatException] (Tarefa 8, spec C.4).
  Uri _sanitizeUri(Uri uri) {
    final safeParams = safeQueryParameters(uri);
    return uri.replace(queryParameters: safeParams);
  }

  bool _isRecentlyProcessed(String fingerprint) {
    final lastProcessedAt = _lastProcessedAt;
    if (_lastProcessedKey != fingerprint || lastProcessedAt == null) {
      return false;
    }
    return _now().difference(lastProcessedAt) < _dedupeWindow;
  }

  void _markProcessed(String fingerprint) {
    _lastProcessedKey = fingerprint;
    _lastProcessedAt = _now();
  }

  void _reportFailure(Object? reason) {
    if (reason is StorageUnavailableException) {
      debugPrint('[deep-link] armazenamento indisponível: $reason');
      _showSnackbar((l10n) => l10n.offlineStorageUnavailable);
    } else {
      debugPrint('[deep-link] falha ao importar: $reason');
      _showSnackbar((l10n) => l10n.deepLinkImportFailed);
    }
  }

  void _navigateAfterImport(Uri uri) {
    final router = ref.read(appRouterProvider);
    final stripped = stripPlaylistShareParams(uri);
    final target = buildHomeLocationFromUri(stripped);
    router.go(target);
  }

  void _showSnackbar(String Function(AppLocalizations l10n) messageBuilder) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = rootNavigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      final l10n = AppLocalizations.of(context);
      if (l10n == null) return;
      showAppSnackbar(context, messageBuilder(l10n));
    });
    // Sem navegação (ex.: falha), nada mais agenda um frame — garante que o
    // postFrameCallback acima realmente rode (Tarefa 8, spec C.4).
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    unawaited(_linkSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
