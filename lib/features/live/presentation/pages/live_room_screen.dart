import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/user_message_for.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/utils/share_position_origin.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../playlists/presentation/providers/playlist_sync_provider.dart';
import '../../../playlists/presentation/providers/playlists_provider.dart';
import '../../data/providers/live_providers.dart';
import '../../domain/entities/live_snapshot.dart';
import '../../domain/live_room_link.dart';
import '../providers/live_session_controller.dart';
import '../providers/my_live_room_provider.dart';

/// `/ao-vivo/:code` — onde o link cai (spec §6.3). Para o consumidor é a
/// página de estado da sala; para o dono, a sala com link, QR e controlos.
class LiveRoomScreen extends ConsumerStatefulWidget {
  const LiveRoomScreen({required this.code, super.key});
  final String code;

  @override
  ConsumerState<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen> {
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(liveSessionProvider.notifier).join(widget.code));
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveSessionProvider);
    final l10n = AppLocalizations.of(context)!;
    final body = state.role == LiveRole.leader && state.code == widget.code
        ? _leader(context, state, l10n)
        : _consumer(context, state, l10n);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.liveRoom)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(padding: const EdgeInsets.all(24), child: body),
          ),
        ),
      ),
    );
  }

  Widget _consumer(
    BuildContext context,
    LiveSessionState state,
    AppLocalizations l10n,
  ) {
    final controller = ref.read(liveSessionProvider.notifier);
    switch (state.phase) {
      case LivePhase.idle:
      case LivePhase.joining:
      case LivePhase.reconnecting:
        return _Message(icon: null, title: l10n.liveJoining, spinner: true);
      case LivePhase.unavailable:
        return _Message(
          icon: Icons.wifi_off,
          title: l10n.liveUnavailableTitle,
          body: l10n.liveUnavailableBody,
          actions: [
            FilledButton(
              onPressed: () => unawaited(controller.join(widget.code)),
              child: Text(l10n.liveRetry),
            ),
          ],
        );
      case LivePhase.notFound:
        return _Message(icon: Icons.link_off, title: l10n.liveNotFound);
      case LivePhase.left:
        return _Message(
          icon: Icons.logout,
          title: l10n.liveLeftTitle,
          actions: [
            FilledButton(
              onPressed: () => unawaited(controller.join(widget.code)),
              child: Text(l10n.liveJoinAgain),
            ),
          ],
        );
      case LivePhase.ended:
        return _ended(context, state, l10n);
      case LivePhase.connected:
        break;
    }
    switch (state.roomStatus) {
      case LiveRoomStatus.live:
        return _Message(
          icon: Icons.sensors,
          title: l10n.liveFollowingTitle(state.ownerName),
          actions: [
            FilledButton(
              onPressed: () => context.go(RoutePaths.home),
              child: Text(l10n.liveGoToList),
            ),
          ],
        );
      case LiveRoomStatus.ended:
        return _ended(context, state, l10n);
      case LiveRoomStatus.idle:
      case LiveRoomStatus.scheduled:
      case LiveRoomStatus.retired:
      case null:
        return _Message(
          icon: Icons.hourglass_top,
          title: l10n.liveIdleTitle(state.ownerName),
          body: l10n.liveIdleBody,
        );
    }
  }

  Widget _ended(
    BuildContext context,
    LiveSessionState state,
    AppLocalizations l10n,
  ) {
    final snapshot = state.snapshot;
    return _Message(
      icon: Icons.stop_circle_outlined,
      title: l10n.liveEndedTitle,
      actions: [
        if (snapshot != null && snapshot.entries.isNotEmpty)
          FilledButton(
            onPressed: _busy ? null : () => unawaited(_saveCopy(state, l10n)),
            child: Text(l10n.liveSaveCopy),
          ),
        TextButton(
          onPressed: () {
            unawaited(ref.read(liveSessionProvider.notifier).leave());
            context.go(RoutePaths.home);
          },
          child: Text(l10n.liveLeave),
        ),
      ],
    );
  }

  Future<void> _saveCopy(LiveSessionState state, AppLocalizations l10n) async {
    final snapshot = state.snapshot;
    if (snapshot == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(saveLiveCopyProvider)(
        snapshot: snapshot,
        copyName: l10n.liveCopyName(snapshot.name, state.ownerName),
      );
      await ref.read(playlistsProvider.notifier).reload();
      unawaited(ref.read(playlistSyncProvider.notifier).sync());
      if (mounted) showAppSnackbar(context, l10n.liveCopySaved);
    } on Object catch (e) {
      if (mounted) showAppSnackbar(context, userMessageFor(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _leader(
    BuildContext context,
    LiveSessionState state,
    AppLocalizations l10n,
  ) {
    final url = liveRoomShareUrl(widget.code);
    final controller = ref.read(liveSessionProvider.notifier);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.liveYourRoom,
            style: AppTypography.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.liveShareHint,
            style: AppTypography.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: QrImageView(
              data: url,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            url,
            textAlign: TextAlign.center,
            style: AppTypography.body,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.copy),
                label: Text(l10n.liveCopyLink),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (context.mounted) {
                    showAppSnackbar(context, l10n.liveLinkCopied);
                  }
                },
              ),
              OutlinedButton.icon(
                icon: Icon(Icons.adaptive.share),
                label: Text(l10n.liveShareLink),
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text: url,
                    sharePositionOrigin:
                        sharePositionOriginFromContextOrFallback(context),
                  ),
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => unawaited(_regenerate(context, l10n)),
                child: Text(l10n.liveRegenerateLink),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            l10n.liveViewers(state.viewers),
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.gold),
          ),
          const SizedBox(height: 16),
          if (state.isLeading)
            FilledButton.icon(
              icon: const Icon(Icons.stop),
              label: Text(l10n.liveEnd),
              onPressed: () async {
                await controller.endLive();
                if (context.mounted) context.go(RoutePaths.playlists);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _regenerate(BuildContext context, AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.liveRegenerateConfirmTitle),
        content: Text(l10n.liveRegenerateConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.liveRegenerateLink),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final wasLive = ref.read(liveSessionProvider).isLeading;
      final playlistId = ref.read(liveSessionProvider).snapshot?.playlistId;
      final info = await ref.read(myLiveRoomProvider.notifier).regenerate();
      // A sala antiga foi aposentada pelo Worker: o socket cai com 4003.
      // Reabrir na nova e, se estava ao vivo, recomeçar a transmissão.
      if (wasLive && playlistId != null) {
        await ref
            .read(liveSessionProvider.notifier)
            .startLive(code: info.code, playlistId: playlistId);
      }
      if (context.mounted) context.go(RoutePaths.liveRoomFor(info.code));
    } on Object {
      if (context.mounted) showAppSnackbar(context, l10n.liveRoomError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.body,
    this.actions = const [],
    this.spinner = false,
  });
  final IconData? icon;
  final String title;
  final String? body;
  final List<Widget> actions;
  final bool spinner;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (spinner)
          const CircularProgressIndicator()
        else if (icon != null)
          Icon(icon, size: 48, color: AppColors.gold),
        const SizedBox(height: 16),
        Text(title, style: AppTypography.headline, textAlign: TextAlign.center),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(body!, style: AppTypography.body, textAlign: TextAlign.center),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: actions,
          ),
        ],
      ],
    );
  }
}
