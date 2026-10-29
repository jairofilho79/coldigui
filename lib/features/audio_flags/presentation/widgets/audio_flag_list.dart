import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/audio_flags/domain/entities/saved_audio_flag.dart';
import 'package:coldigui/features/audio_flags/presentation/utils/audio_flag_time_format.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Lista de marcadores (página de áudio) — tap seek, delete.
class AudioFlagList extends StatelessWidget {
  const AudioFlagList({
    required this.flags,
    required this.onSeek,
    required this.onDelete,
    super.key,
  });

  final List<SavedAudioFlag> flags;
  final ValueChanged<SavedAudioFlag> onSeek;
  final ValueChanged<SavedAudioFlag> onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (flags.isEmpty) {
      return Text(
        l10n.audioFlagListEmpty,
        textAlign: TextAlign.center,
        style: AppTypography.body.copyWith(
          color: AppColors.textLight.withValues(alpha: 0.7),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: flags.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: AppColors.textLight.withValues(alpha: 0.15),
      ),
      itemBuilder: (context, index) {
        final flag = flags[index];
        final time = formatAudioFlagTime(flag.position);
        final label = flag.label.trim().isEmpty ? '—' : flag.label.trim();
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.flag, color: AppColors.goldLight, size: 20),
          title: Text(
            label,
            style: AppTypography.body.copyWith(color: AppColors.textLight),
          ),
          subtitle: Text(
            time,
            style: AppTypography.label.copyWith(
              color: AppColors.textLight.withValues(alpha: 0.7),
            ),
          ),
          trailing: IconButton(
            tooltip: l10n.audioFlagDelete,
            onPressed: () => onDelete(flag),
            icon: Icon(
              Icons.delete_outline,
              color: AppColors.textLight.withValues(alpha: 0.85),
            ),
          ),
          onTap: () => onSeek(flag),
        );
      },
    );
  }
}
