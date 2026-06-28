import 'package:flutter/material.dart';

import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/playlist_share_option.dart';

/// Bottom sheet — escolha do modo de compartilhamento (UC-07/UC-08).
Future<PlaylistShareOption?> showPlaylistShareSheet(BuildContext context) {
  return showModalBottomSheet<PlaylistShareOption>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => const _PlaylistShareSheetBody(),
  );
}

class _PlaylistShareSheetBody extends StatelessWidget {
  const _PlaylistShareSheetBody();

  static const _whatsappGreen = Color(0xFF25D366);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, 8, 0, 8 + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Text(
                  l10n.playlistShareSheetTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.title,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              _ShareOptionTile(
                icon: Icons.link,
                title: l10n.playlistShareOptionLink,
                subtitle: l10n.playlistShareOptionLinkSubtitle,
                onTap: () => Navigator.pop(context, PlaylistShareOption.link),
              ),
              _ShareOptionTile(
                icon: Icons.description_outlined,
                title: l10n.playlistShareOptionLeaflet,
                subtitle: l10n.playlistShareOptionLeafletSubtitle,
                onTap: () =>
                    Navigator.pop(context, PlaylistShareOption.leaflet),
              ),
              _ShareOptionTile(
                icon: Icons.share_outlined,
                title: l10n.playlistShareOptionLinkWithLeaflet,
                subtitle: l10n.playlistShareOptionLinkWithLeafletSubtitle,
                onTap: () => Navigator.pop(
                  context,
                  PlaylistShareOption.linkWithLeaflet,
                ),
              ),
              _ShareOptionTile(
                icon: Icons.chat_bubble_outline,
                iconColor: _whatsappGreen,
                title: l10n.playlistShareOptionWhatsApp,
                subtitle: l10n.playlistShareOptionWhatsAppSubtitle,
                onTap: () => Navigator.pop(
                  context,
                  PlaylistShareOption.linkAndLeafletWhatsApp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareOptionTile extends StatelessWidget {
  const _ShareOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.title),
      title: Text(
        title,
        style: TextStyle(
          color: AppColors.title,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppColors.placeholder),
      ),
      onTap: onTap,
    );
  }
}
