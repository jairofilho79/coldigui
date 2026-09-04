import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/user_message_for.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/playlist_sync_provider.dart';

/// Aviso discreto de sync na tela de listas (spec A.7).
///
/// Some quando não há nada a dizer. Aparece quando a última sync guardou um
/// erro — traduzido aqui por [userMessageFor], já que o notifier não tem
/// `BuildContext` — ou quando alguma lista ficou em conflito. "Tentar
/// novamente" redispara a sync; um sucesso limpa o estado e o banner some.
class PlaylistSyncErrorBanner extends ConsumerWidget {
  const PlaylistSyncErrorBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sync = ref.watch(playlistSyncProvider);
    if (!sync.hasProblem) return const SizedBox.shrink();

    final cause = sync.lastErrorCause;
    final conflicts = sync.conflicts;
    // Erro e conflito não são o mesmo problema e podem coexistir: o erro vira
    // título + detalhe, e a contagem de conflitos entra como linha própria.
    final title = cause != null
        ? l10n.playlistSyncFailed
        : l10n.playlistSyncConflicts(conflicts);
    final details = <String>[
      if (cause != null) userMessageFor(l10n, cause),
      if (cause != null && conflicts > 0) l10n.playlistSyncConflicts(conflicts),
    ];
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gold),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 18,
                color: AppColors.title,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.title,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    for (final detail in details)
                      Text(
                        detail,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textDark,
                        ),
                      ),
                  ],
                ),
              ),
              TextButton(
                // Todo o "sincroniza e recarrega" vive no notifier: o retry
                // sobrevive a sair da tela, o que um `WidgetRef` não garante.
                onPressed: () =>
                    ref.read(playlistSyncProvider.notifier).retryAndReload(),
                style: TextButton.styleFrom(foregroundColor: AppColors.title),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
