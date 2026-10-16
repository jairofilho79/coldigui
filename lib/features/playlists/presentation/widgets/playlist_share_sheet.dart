import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../../core/theme/color_extensions.dart';
import '../../../../core/tutorial/presentation/providers/tutorial_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/playlist_share_option.dart';

/// Bottom sheet — Folheto (imagem + link) ou Só o link (spec short-id-share D9).
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

class _PlaylistShareSheetBody extends StatefulWidget {
  const _PlaylistShareSheetBody();

  @override
  State<_PlaylistShareSheetBody> createState() =>
      _PlaylistShareSheetBodyState();
}

class _PlaylistShareSheetBodyState extends State<_PlaylistShareSheetBody> {
  final _portalController = SpotlightGuidePortalController();
  TutorialController? _tutorialController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tutorialController == null) {
      try {
        _tutorialController = ProviderScope.containerOf(
          context,
          listen: false,
        ).read(tutorialControllerProvider);
        _tutorialController?.pushPortalController(_portalController);
      } catch (_) {
        _tutorialController = null;
      }
    }
  }

  @override
  void dispose() {
    try {
      if (_portalController.isShowing) {
        _portalController.hide();
      }
      _tutorialController?.popPortalController(_portalController);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return SpotlightGuidePortal(
      controller: _portalController,
      autoStart: false,
      missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
      barrier: const SpotlightGuideBarrierStyle(
        color: Color(0x99000000),
        blurSigma: 0,
      ),
      barrierDismissBehavior: SpotlightGuideDismissBehavior.anytime,
      onBarrierTap: (c) => _tutorialController?.hide(),
      onFinish: () => _tutorialController?.resetTutorialState(),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(0, 8, 0, 8 + bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.playlistShareSheetTitle,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.title,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      SpotlightGuideTarget(
                        id: 'playlist-share-info',
                        child: IconButton(
                          icon: const Icon(
                            Icons.info_outline,
                            size: 20,
                            color: AppColors.title,
                          ),
                          tooltip: 'Como compartilhar',
                          onPressed: () => _tutorialController
                              ?.startPlaylistShareTutorial(context),
                        ),
                      ),
                    ],
                  ),
                ),
                SpotlightGuideTarget(
                  id: 'playlist-share-leaflet',
                  child: _ShareOptionTile(
                    icon: Icons.description_outlined,
                    title: l10n.playlistShareOptionLinkWithLeaflet,
                    subtitle: l10n.playlistShareOptionLinkWithLeafletSubtitle,
                    onTap: () => Navigator.pop(
                      context,
                      PlaylistShareOption.linkWithLeaflet,
                    ),
                  ),
                ),
                SpotlightGuideTarget(
                  id: 'playlist-share-link',
                  child: _ShareOptionTile(
                    icon: Icons.link,
                    title: l10n.playlistShareOptionLink,
                    subtitle: l10n.playlistShareOptionLinkSubtitle,
                    onTap: () =>
                        Navigator.pop(context, PlaylistShareOption.link),
                  ),
                ),
              ],
            ),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.title),
      title: Text(
        title,
        style: TextStyle(color: AppColors.title, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: AppColors.placeholder)),
      onTap: onTap,
    );
  }
}
