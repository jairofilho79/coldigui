import 'package:flutter/material.dart';

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
  State<_PublishPlaylistDialog> createState() => _PublishPlaylistDialogState();
}

class _PublishPlaylistDialogState extends State<_PublishPlaylistDialog> {
  PlaylistCategory? _category;
  var _reach = PlaylistReach.usual;
  var _showCategoryError = false;

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

    return AlertDialog(
      title: Text(l10n.playlistPublishTitle),
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
            Wrap(
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
            if (_showCategoryError) ...[
              const SizedBox(height: 8),
              Text(
                l10n.playlistPublishCategoryRequired,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            SwitchListTile(
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.playlistPublishCancel),
        ),
        TextButton(
          onPressed: () {
            final category = _category;
            if (category == null) {
              setState(() => _showCategoryError = true);
              return;
            }
            Navigator.of(
              context,
            ).pop(PublishPlaylistResult(category: category, reach: _reach));
          },
          child: Text(l10n.playlistPublishConfirm),
        ),
      ],
    );
  }
}
