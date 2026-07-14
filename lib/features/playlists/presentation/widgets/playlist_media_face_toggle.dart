import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_media_face.dart';
import 'package:coldigui/features/playlists/presentation/providers/playlist_media_face_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Segmented control PDF ↔ Áudio (face do paralelepípedo da playlist).
class PlaylistMediaFaceToggle extends ConsumerWidget {
  const PlaylistMediaFaceToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final face = ref.watch(playlistMediaFaceProvider);

    return Semantics(
      label: l10n.playlistFaceToggleSemantics,
      child: SegmentedButton<PlaylistMediaFace>(
        segments: [
          ButtonSegment(
            value: PlaylistMediaFace.pdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: Text(l10n.playlistFacePdf),
            tooltip: l10n.playlistFacePdf,
          ),
          ButtonSegment(
            value: PlaylistMediaFace.audio,
            icon: const Icon(LouvorMaterialIcons.audio, size: 18),
            label: Text(l10n.playlistFaceAudio),
            tooltip: l10n.playlistFaceAudio,
          ),
        ],
        selected: {face},
        onSelectionChanged: (next) {
          final selected = next.first;
          ref.read(playlistMediaFaceProvider.notifier).setFace(selected);
        },
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.title;
            }
            return AppColors.textLight.withValues(alpha: 0.85);
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.card;
            }
            return AppColors.btnBackground;
          }),
        ),
      ),
    );
  }
}
