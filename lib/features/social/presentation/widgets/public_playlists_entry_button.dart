import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';

/// Entrada para as listas públicas (antiga aba Social) dentro de Listas —
/// linha própria, alinhada à direita, logo abaixo do banner de sync.
///
/// `push` (não `go`): a tela abre em cima de `/listas`, e a seta da
/// `PlpcgPrimaryAppBar` volta para a lista com `pop`.
class PublicPlaylistsEntryButton extends StatelessWidget {
  const PublicPlaylistsEntryButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: () => context.push(RoutePaths.publicPlaylists),
          icon: const Icon(Icons.public, size: 18),
          label: Text(l10n.publicPlaylistsTitle),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textLight,
            side: BorderSide(color: AppColors.gold.withValues(alpha: 0.6)),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}
