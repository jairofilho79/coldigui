import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/user_message_for.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/audio_flag_sync_provider.dart';

/// Aviso discreto de sync de marcadores no player (spec A.4).
///
/// Some quando não há nada a dizer. Aparece quando a última sync guardou um
/// erro — traduzido aqui por [userMessageFor], já que o notifier não tem
/// `BuildContext` — ou quando algum marcador ficou em conflito. "Tentar
/// novamente" refaz a adoção pendente ou redispara a sync; um sucesso limpa o
/// estado e a linha some.
class AudioFlagSyncErrorRow extends ConsumerWidget {
  const AudioFlagSyncErrorRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sync = ref.watch(audioFlagSyncProvider);
    if (!sync.hasProblem) return const SizedBox.shrink();

    final cause = sync.lastErrorCause;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 16,
            color: AppColors.textLight.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.audioFlagsSyncFailed,
                  style: AppTypography.label.copyWith(
                    color: AppColors.textLight,
                  ),
                ),
                if (cause != null)
                  Text(
                    userMessageFor(l10n, cause),
                    style: AppTypography.label.copyWith(
                      color: AppColors.textLight.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            // Todo o "sincroniza e recarrega" vive no notifier: o retry
            // sobrevive a sair da tela, o que um `WidgetRef` não garante.
            onPressed: () =>
                ref.read(audioFlagSyncProvider.notifier).retryAndReload(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.goldLight,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}
