import 'package:coldigui/core/theme/app_typography.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/widgets/app_snackbar.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvor_pdf_download_provider.dart';
import 'package:coldigui/features/catalog/presentation/utils/open_louvor_in_reader.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_missing_louvores_provider.dart';
import 'package:coldigui/features/offline/presentation/utils/pdf_offline_error_ui.dart';
import 'package:coldigui/features/pdf_opening/domain/entities/pdf_offline_availability.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom sheet — louvores faltantes de um material (long-press no chip UC-10).
Future<void> showOfflineMissingLouvoresSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String material,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => OfflineMissingLouvoresSheetBody(material: material),
  );
}

class OfflineMissingLouvoresSheetBody extends ConsumerWidget {
  const OfflineMissingLouvoresSheetBody({required this.material, super.key});

  final String material;

  Future<void> _openLouvor(
    BuildContext context,
    WidgetRef ref,
    Louvor louvor,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await openLouvorInReader(ref: ref, context: context, louvor: louvor);
    } on PdfOfflineUnavailableException catch (e) {
      if (context.mounted) {
        showPdfOfflineUnavailableSnackbar(context, message: e.message);
      }
    } on Object catch (e) {
      if (context.mounted) {
        showAppSnackbar(context, louvorPdfErrorMessage(e, l10n.pdfActionError));
      }
    }
  }

  CarouselItem _toCarouselItem(Louvor louvor) {
    return CarouselItem(
      pdfId: louvor.pdfId,
      sortOrder: 0,
      numero: louvor.numero,
      nome: louvor.nome,
      categoria: louvor.categoria,
      classificacao: louvor.classificacao,
      source: louvor.source,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final louvoresAsync = ref.watch(offlineMissingLouvoresProvider(material));
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

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
                    l10n.offlineMissingLouvoresSheetTitle(material),
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
              child: louvoresAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (_, _) => Center(
                  child: Text(
                    l10n.offlineMissingLouvoresLoadError,
                    style: AppTypography.body.copyWith(color: AppColors.title),
                    textAlign: TextAlign.center,
                  ),
                ),
                data: (louvores) {
                  if (louvores.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.offlineMissingLouvoresEmpty,
                        style: AppTypography.body.copyWith(
                          color: AppColors.title.withValues(alpha: 0.75),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: louvores.length,
                    itemBuilder: (context, index) {
                      final louvor = louvores[index];
                      final downloadState = ref.watch(
                        louvorPdfDownloadProvider.select(
                          (states) => states[louvor.pdfId],
                        ),
                      );
                      final isLoading = downloadState?.isLoading ?? false;

                      return CarouselLouvorChip(
                        item: _toCarouselItem(louvor),
                        onTap: isLoading
                            ? null
                            : () async {
                                Navigator.of(context).pop();
                                await _openLouvor(context, ref, louvor);
                              },
                        loading: isLoading,
                        offlineAvailability:
                            PdfOfflineAvailability.notAvailable,
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
