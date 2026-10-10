import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/theme/color_extensions.dart';
import '../../../../../core/widgets/golden_tagged_container.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../gestures/data/providers/gesture_providers.dart';
import '../../../../gestures/domain/entities/gesture_dictionary.dart';
import '../../../../gestures/presentation/theme/gesture_reader_theme.dart';
import '../../../../gestures/presentation/widgets/gesture_figure.dart';

/// Modal para escolha e substituição de gesto CIAs pelo dicionário oficial.
class GesturePickerModal extends ConsumerStatefulWidget {
  const GesturePickerModal({this.currentGestureId, super.key});

  final String? currentGestureId;

  static Future<String?> show(
    BuildContext context, {
    String? currentGestureId,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GesturePickerModal(currentGestureId: currentGestureId),
    );
  }

  @override
  ConsumerState<GesturePickerModal> createState() => _GesturePickerModalState();
}

class _GesturePickerModalState extends ConsumerState<GesturePickerModal> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dictAsync = ref.watch(gestureDictionaryProvider);
    final palette = GestureReaderMode.light.palette;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        maxWidth: 720,
      ),
      margin: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    l10n.contributeEditorSelectGesture,
                    style: AppTypography.headline.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textLight,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textLight),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: GoldenTaggedContainer(
                label: l10n.socialSearchHint,
                contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: AppTypography.input,
                  decoration: InputDecoration(
                    hintText: l10n.contributeEditorSearchGesture,
                    hintStyle: AppTypography.hint(italic: true),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : const Icon(Icons.search, size: 20, color: AppColors.gold),
                  ),
                  onChanged: (val) => setState(() => _query = val.trim().toLowerCase()),
                ),
              ),
            ),
            const Divider(color: Color(0x33D4AF37), height: 16),
            Expanded(
              child: dictAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (err, _) => Center(
                  child: Text(
                    err.toString(),
                    style: AppTypography.body.copyWith(color: AppColors.textLight),
                  ),
                ),
                data: (dict) {
                  if (dict == null || dict.byId.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.contributeEditorNoGestureFound,
                        style: AppTypography.body.copyWith(color: AppColors.textLight),
                      ),
                    );
                  }

                  final allEntries = dict.byId.values
                      .where((e) => e.status == GestureStatus.active)
                      .toList()
                    ..sort((a, b) => a.name.compareTo(b.name));

                  final filtered = _query.isEmpty
                      ? allEntries
                      : allEntries.where((e) {
                          final nameMatch = e.name.toLowerCase().contains(_query);
                          final triggerMatch = e.exampleTriggers.any(
                            (t) => t.toLowerCase().contains(_query),
                          );
                          final descMatch = e.description.toLowerCase().contains(_query);
                          return nameMatch || triggerMatch || descMatch;
                        }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.contributeEditorNoGestureFound,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textLight.withValues(alpha: 0.7),
                        ),
                      ),
                    );
                  }

                  final isWide = MediaQuery.sizeOf(context).width >= 560;
                  final crossAxisCount = isWide ? 3 : 2;

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      final isSelected = entry.id == widget.currentGestureId;

                      return InkWell(
                        onTap: () => Navigator.of(context).pop(entry.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.gold.withValues(alpha: 0.25)
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.gold
                                  : const Color(0x33D4AF37),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureFigure(
                                entry: entry,
                                gestureId: entry.id,
                                side: 64,
                                palette: palette,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                entry.name,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.title,
                                ),
                              ),
                              if (entry.exampleTriggers.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  entry.exampleTriggers.take(2).join(', '),
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.label.copyWith(
                                    fontSize: 11,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
