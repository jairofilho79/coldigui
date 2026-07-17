import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/entities/youtube_material.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_material_icons.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Callback de adição de um material PDF ao carousel no sheet.
typedef LouvorMaterialAddCallback = Future<void> Function(Louvor louvor);

/// Callback de adição de áudio à playlist ativa.
typedef LouvorAudioAddCallback = Future<void> Function(AudioTrack track);

/// Bottom sheet — escolha de material por classificação → categoria (+ áudios).
///
/// Exibido quando [LouvorGroup.totalMaterials] > 1. Seções ordenadas por
/// [LouvorMaterialSection.displayLabel]; materiais por [LouvorCategoryOrder].
/// Áudios e YouTube Coldigom aparecem em seções finais.
Future<void> showLouvorMaterialSheet({
  required BuildContext context,
  required LouvorGroup group,
  required ValueChanged<Louvor> onMaterialSelected,
  ValueChanged<AudioTrack>? onAudioSelected,
  ValueChanged<YoutubeMaterial>? onYoutubeSelected,
  LouvorMaterialAddCallback? onMaterialAdd,
  LouvorAudioAddCallback? onAudioAdd,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return _LouvorMaterialSheetBody(
        group: group,
        onMaterialSelected: onMaterialSelected,
        onAudioSelected: onAudioSelected,
        onYoutubeSelected: onYoutubeSelected,
        onMaterialAdd: onMaterialAdd,
        onAudioAdd: onAudioAdd,
      );
    },
  );
}

class _LouvorMaterialSheetBody extends ConsumerStatefulWidget {
  const _LouvorMaterialSheetBody({
    required this.group,
    required this.onMaterialSelected,
    this.onAudioSelected,
    this.onYoutubeSelected,
    this.onMaterialAdd,
    this.onAudioAdd,
  });

  final LouvorGroup group;
  final ValueChanged<Louvor> onMaterialSelected;
  final ValueChanged<AudioTrack>? onAudioSelected;
  final ValueChanged<YoutubeMaterial>? onYoutubeSelected;
  final LouvorMaterialAddCallback? onMaterialAdd;
  final LouvorAudioAddCallback? onAudioAdd;

  @override
  ConsumerState<_LouvorMaterialSheetBody> createState() =>
      _LouvorMaterialSheetBodyState();
}

class _LouvorMaterialSheetBodyState
    extends ConsumerState<_LouvorMaterialSheetBody> {
  String? _addingId;

  Future<void> _handleAddPdf(Louvor louvor) async {
    final onAdd = widget.onMaterialAdd;
    if (onAdd == null || _addingId != null) return;

    setState(() => _addingId = louvor.pdfId);
    try {
      await onAdd(louvor);
    } finally {
      if (mounted) setState(() => _addingId = null);
    }
  }

  Future<void> _handleAddAudio(AudioTrack track) async {
    final onAdd = widget.onAudioAdd;
    if (onAdd == null || _addingId != null) return;

    setState(() => _addingId = track.audioId);
    try {
      await onAdd(track);
    } finally {
      if (mounted) setState(() => _addingId = null);
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Text(
        text,
        style: AppTypography.label.copyWith(
          color: AppColors.title,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final group = widget.group;
    final onMaterialAdd = widget.onMaterialAdd;
    final onAudioAdd = widget.onAudioAdd;
    final carouselPdfIds = ref.watch(carouselPdfIdsProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    group.numero.isNotEmpty
                        ? '${group.numero} — ${group.nome}'
                        : group.nome,
                    style: AppTypography.headline.copyWith(
                      color: AppColors.title,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.carouselListClose,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.title),
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: AppColors.gold, height: 1, thickness: 1.5),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final section in group.sections) ...[
                    _sectionLabel(section.displayLabel),
                    for (final material in section.materials)
                      ListTile(
                        leading: Icon(
                          LouvorMaterialIcons.forCategory(material.categoria),
                          color: AppColors.title,
                        ),
                        title: Text(
                          material.categoria,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textDark,
                          ),
                        ),
                        trailing: onMaterialAdd == null
                            ? null
                            : _MaterialAddTrailing(
                                isAdded: carouselPdfIds.contains(
                                  material.pdfId,
                                ),
                                isAdding: _addingId == material.pdfId,
                                onAdd: () => _handleAddPdf(material.louvor),
                              ),
                        onTap: () {
                          Navigator.of(context).pop();
                          // Pós-frame: evita race push vs pop (modal ainda no stack).
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            widget.onMaterialSelected(material.louvor);
                          });
                        },
                      ),
                  ],
                  if (group.audioTracks.isNotEmpty) ...[
                    _sectionLabel(l10n.audioMaterialSection),
                    for (final track in group.audioTracks)
                      ListTile(
                        leading: const Icon(
                          LouvorMaterialIcons.audio,
                          color: AppColors.title,
                        ),
                        title: Text(
                          track.categoria,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textDark,
                          ),
                        ),
                        subtitle: track.author.isEmpty
                            ? null
                            : Text(
                                track.author,
                                style: AppTypography.label.copyWith(
                                  color: AppColors.textDark.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                        trailing: onAudioAdd == null
                            ? null
                            : _MaterialAddTrailing(
                                isAdded: false,
                                isAdding: _addingId == track.audioId,
                                onAdd: () => _handleAddAudio(track),
                              ),
                        onTap: () {
                          Navigator.of(context).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            widget.onAudioSelected?.call(track);
                          });
                        },
                      ),
                  ],
                  if (group.youtubeMaterials.isNotEmpty) ...[
                    _sectionLabel(l10n.youtubeMaterialSection),
                    for (final item in group.youtubeMaterials)
                      ListTile(
                        leading: const Icon(
                          LouvorMaterialIcons.youtube,
                          color: AppColors.youtube,
                        ),
                        title: Text(
                          item.categoria,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textDark,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            widget.onYoutubeSelected?.call(item);
                          });
                        },
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialAddTrailing extends StatelessWidget {
  const _MaterialAddTrailing({
    required this.isAdded,
    required this.isAdding,
    required this.onAdd,
  });

  final bool isAdded;
  final bool isAdding;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (isAdding) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.title,
        ),
      );
    }
    if (isAdded) {
      return DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.title, width: 1.5),
        ),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: Icon(Icons.check, size: 16, color: AppColors.title),
        ),
      );
    }
    return CarouselLouvorAddButton(onPressed: onAdd);
  }
}
