import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../carousel/presentation/widgets/carousel_louvor_chip.dart';
import '../../../playlists/presentation/providers/active_playlist_editor.dart';
import '../../domain/entities/catalog_material.dart';

/// Só PDF e áudio entram numa lista — cifra e YouTube não têm entrada própria.
bool canAddMaterialToPlaylist(CatalogMaterial material) {
  return material is PdfMaterial || material is AudioMaterial;
}

/// Trailing `+` / spinner / «Adicionar de novo» de uma linha do sheet.
///
/// Com [isAdded] a linha deixa de ser um ✓ morto: a lista ativa aceita
/// repetição (B.1), então o material já presente ganha a ação
/// «Adicionar de novo» — o ✓ fica como sinal de que ele já está lá.
class MaterialAddTrailing extends StatelessWidget {
  const MaterialAddTrailing({
    required this.isAdded,
    required this.isAdding,
    required this.onAdd,
    required this.addAgainLabel,
    super.key,
  });

  final bool isAdded;
  final bool isAdding;
  final VoidCallback onAdd;

  /// Rótulo de «Adicionar de novo» (`l10n.materialAddAgain`).
  final String addAgainLabel;

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
      return TextButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.check, size: 16, color: AppColors.title),
        label: Text(addAgainLabel),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.title,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: AppTypography.label.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return CarouselLouvorAddButton(onPressed: onAdd);
  }
}

/// Adiciona [material] à lista ativa e mostra a snackbar do resultado.
///
/// Passa pelo [ActivePlaylistEditor] (B.3): o `kind` vem do próprio
/// [CatalogMaterial], não da extensão do id. [allowDuplicate] é o caminho de
/// «Adicionar de novo» — uma segunda ocorrência do mesmo material.
Future<void> addMaterialToActivePlaylist({
  required BuildContext context,
  required WidgetRef ref,
  required CatalogMaterial material,
  bool allowDuplicate = false,
}) async {
  final l10n = AppLocalizations.of(context)!;

  if (!ref.read(isarAvailableProvider)) {
    if (context.mounted) {
      showAppSnackbar(context, l10n.playlistStorageUnavailable);
    }
    return;
  }

  // canAddMaterialToPlaylist barra cifra e YouTube antes de chegar aqui.
  if (!canAddMaterialToPlaylist(material)) return;

  final outcome = await ref
      .read(activePlaylistEditorProvider.notifier)
      .addToActive(
        material.id,
        kind: material.kind,
        allowDuplicate: allowDuplicate,
      );

  if (!context.mounted) return;
  showAppSnackbar(context, switch (outcome) {
    AddToActiveOutcome.added => l10n.carouselAdded,
    AddToActiveOutcome.alreadyPresent => l10n.carouselAlreadyAdded,
    AddToActiveOutcome.storageUnavailable => l10n.playlistStorageUnavailable,
  });
}
