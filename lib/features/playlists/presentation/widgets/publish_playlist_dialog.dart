import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../../core/tutorial/presentation/providers/tutorial_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/saved_playlist.dart';

/// Resultado do diálogo de publicação.
class PublishPlaylistResult {
  const PublishPlaylistResult({required this.category, required this.reach});

  final PlaylistCategory category;
  final PlaylistReach reach;
}

/// Confirma publicação irreversível + categoria + alcance.
Future<PublishPlaylistResult?> showPublishPlaylistDialog(BuildContext context) {
  return showDialog<PublishPlaylistResult>(
    context: context,
    builder: (dialogContext) => const _PublishPlaylistDialog(),
  );
}

class _PublishPlaylistDialog extends StatefulWidget {
  const _PublishPlaylistDialog();

  @override
  State<_PublishPlaylistDialog> createState() =>
      _PublishPlaylistDialogState();
}

class _PublishPlaylistDialogState extends State<_PublishPlaylistDialog> {
  final _portalController = SpotlightGuidePortalController();
  TutorialController? _tutorialController;
  PlaylistCategory? _category;
  var _reach = PlaylistReach.usual;
  var _showCategoryError = false;

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

  String _categoryLabel(AppLocalizations l10n, PlaylistCategory category) {
    return switch (category) {
      PlaylistCategory.evangelizacao => l10n.playlistCategoryEvangelizacao,
      PlaylistCategory.aprendizado => l10n.playlistCategoryAprendizado,
      PlaylistCategory.medleys => l10n.playlistCategoryMedleys,
      PlaylistCategory.cultoEspecial => l10n.playlistCategoryCultoEspecial,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
      child: AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(l10n.playlistPublishTitle)),
            SpotlightGuideTarget(
              id: 'publish-playlist-info',
              child: IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                tooltip: l10n.tutorialTooltipHowToPublish,
                onPressed: () => _tutorialController
                    ?.startPublishPlaylistTutorial(context),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.playlistPublishMessage),
              const SizedBox(height: 16),
              Text(
                l10n.playlistPublishCategoryLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SpotlightGuideTarget(
                id: 'publish-playlist-category',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in PlaylistCategory.values)
                      ChoiceChip(
                        label: Text(_categoryLabel(l10n, category)),
                        selected: _category == category,
                        onSelected: (_) {
                          setState(() {
                            _category = category;
                            _showCategoryError = false;
                          });
                        },
                      ),
                  ],
                ),
              ),
              if (_showCategoryError) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.playlistPublishCategoryRequired,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              SpotlightGuideTarget(
                id: 'publish-playlist-reach',
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.playlistPublishReachLabel),
                  subtitle: Text(
                    _reach == PlaylistReach.usual
                        ? l10n.playlistPublishReachUsual
                        : l10n.playlistPublishReachPontual,
                  ),
                  value: _reach == PlaylistReach.pontual,
                  onChanged: (pontual) {
                    setState(() {
                      _reach = pontual
                          ? PlaylistReach.pontual
                          : PlaylistReach.usual;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.playlistPublishCancel),
          ),
          SpotlightGuideTarget(
            id: 'publish-playlist-confirm',
            child: TextButton(
              onPressed: () {
                final category = _category;
                if (category == null) {
                  setState(() => _showCategoryError = true);
                  return;
                }
                Navigator.of(context).pop(
                  PublishPlaylistResult(category: category, reach: _reach),
                );
              },
              child: Text(l10n.playlistPublishConfirm),
            ),
          ),
        ],
      ),
    );
  }
}
