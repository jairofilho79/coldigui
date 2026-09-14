import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/live_snapshot.dart';
import '../../domain/live_room_link.dart';
import '../providers/live_leader_session_prefs.dart';
import '../providers/live_session_controller.dart';

/// Faixa persistente acima da barra da lista ativa (spec §6.3): diz a quem
/// segue quem está a seguir, e ao gestor quantos seguem. Um widget para os
/// dois papéis — a barra não tem largura para um indicador próprio.
class LiveSessionBanner extends ConsumerWidget {
  const LiveSessionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(liveSessionProvider);
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(liveSessionProvider.notifier);

    if (state.phase == LivePhase.idle) {
      final pending = ref.watch(pendingLeaderSessionProvider);
      if (pending == null) return const SizedBox.shrink();
      return _Bar(
        icon: Icons.sensors,
        text: l10n.liveWasLive(pending.playlistName),
        actions: [
          _Action(
            l10n.liveResume,
            () => unawaited(controller.resumeLeader(pending)),
          ),
          _Action(
            l10n.liveEnd,
            () => unawaited(controller.discardLeaderSession()),
          ),
        ],
      );
    }

    if (state.phase == LivePhase.reconnecting) {
      return _Bar(
        icon: Icons.sync,
        text: l10n.liveReconnecting,
        actions: [_Action(l10n.liveLeave, () => unawaited(controller.leave()))],
      );
    }

    if (state.role == LiveRole.leader) {
      if (state.phase == LivePhase.ended &&
          state.endReason == LiveEndReason.replaced) {
        return _Bar(
          icon: Icons.devices_other,
          text: l10n.liveReplacedElsewhere,
          actions: [_Action(l10n.liveOk, () => unawaited(controller.leave()))],
        );
      }
      if (state.isLeading) {
        final code = state.code!;
        return _Bar(
          icon: Icons.sensors,
          text: l10n.liveOnAir(state.viewers),
          actions: [
            _Action(l10n.liveRoom, () => context.go(liveRoomRouteFor(code))),
            _Action(
              l10n.liveEnd,
              () => unawaited(_confirmEnd(context, l10n, controller)),
            ),
          ],
        );
      }
      return const SizedBox.shrink();
    }

    if (state.phase != LivePhase.connected) return const SizedBox.shrink();

    if (state.isFollowing) {
      final away = state.leaderPresent ? '' : ' · ${l10n.liveLeaderAway}';
      return _Bar(
        icon: Icons.sensors,
        text:
            '${l10n.liveFollowing(state.ownerName, state.snapshot?.name ?? '')}$away',
        actions: [
          if (!state.followingFocus)
            _Action(l10n.liveReturnToLeader, controller.returnToLeader),
          _Action(l10n.liveLeave, () => unawaited(controller.leave())),
        ],
      );
    }
    return _Bar(
      icon: Icons.hourglass_top,
      text: l10n.liveWaitingFor(state.ownerName),
      actions: [_Action(l10n.liveLeave, () => unawaited(controller.leave()))],
    );
  }

  Future<void> _confirmEnd(
    BuildContext context,
    AppLocalizations l10n,
    LiveSessionController controller,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.liveEndConfirmTitle),
        content: Text(l10n.liveEndConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.liveEnd),
          ),
        ],
      ),
    );
    if (ok == true) await controller.endLive();
  }
}

class _Action {
  const _Action(this.label, this.onPressed);
  final String label;
  final VoidCallback onPressed;
}

class _Bar extends StatelessWidget {
  const _Bar({required this.icon, required this.text, required this.actions});
  final IconData icon;
  final String text;
  final List<_Action> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.gold.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          runSpacing: 0,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.gold, size: 20),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    text,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textLight,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final action in actions)
                  TextButton(
                    onPressed: action.onPressed,
                    child: Text(action.label),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
