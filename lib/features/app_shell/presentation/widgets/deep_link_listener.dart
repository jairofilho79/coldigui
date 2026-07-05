import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/home_url_builder.dart';
import '../../../../core/utils/playlist_share_url_builder.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../playlists/presentation/providers/playlists_provider.dart';
import '../../data/providers/app_shell_providers.dart';
import '../../domain/usecases/sync_deep_link_state.dart';
import '../utils/deep_link_initial_uri.dart';

/// UC-14 — Observa deep links e importa playlist compartilhada (Fase 4.5).
///
/// Montado em [ColdiguiApp] — subscription `app_links` (initial + stream),
/// dedupe por fingerprint, snackbar e navegação pós-import.
class DeepLinkListener extends ConsumerStatefulWidget {
  const DeepLinkListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DeepLinkListener> createState() => DeepLinkListenerState();
}

class DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  StreamSubscription<Uri>? _linkSubscription;
  String? _lastProcessedKey;
  var _handling = false;

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

    if (kIsWeb) {
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

    final params = parsePlaylistShareParams(uri);
    if (params == null) return;

    final fingerprint = '${params.sharePdfs}|${params.shareName}';
    if (_lastProcessedKey == fingerprint) return;

    _handling = true;
    try {
      final result = await ref.read(syncDeepLinkStateProvider)(uri: uri);
      if (!mounted) return;

      switch (result.outcome) {
        case SyncDeepLinkOutcome.skipped:
          return;
        case SyncDeepLinkOutcome.success:
          _lastProcessedKey = fingerprint;
          await ref.read(playlistsProvider.notifier).refreshAfterImport();
          if (!mounted) return;
          _navigateAfterImport(uri);
          _showSnackbar((l10n) => l10n.playlistImported);
        case SyncDeepLinkOutcome.invalid:
          _lastProcessedKey = fingerprint;
          _navigateAfterImport(uri);
          _showSnackbar((l10n) => l10n.playlistImportInvalidUrl);
      }
    } finally {
      _handling = false;
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
  }

  @override
  void dispose() {
    unawaited(_linkSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
