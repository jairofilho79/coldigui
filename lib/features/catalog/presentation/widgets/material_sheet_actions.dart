import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/color_extensions.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../carousel/presentation/widgets/chip_parts/chip_buttons.dart';
import '../../../playlists/presentation/providers/active_playlist_editor.dart';
import '../../domain/entities/catalog_material.dart';

/// Só PDF e áudio entram numa lista — cifra e YouTube não têm entrada própria.
bool canAddMaterialToPlaylist(CatalogMaterial material) {
  return material is PdfMaterial || material is AudioMaterial;
}

/// Trailing `+` / spinner / `×` de uma linha do sheet.
///
/// Com [isAdded] a linha vira um `×` que tira o material da lista: o ✓ com
/// «Adicionar de novo» repetia a entrada sem que ninguém quisesse (onda 4.4),
/// e a repetição continua possível pela própria lista. A remoção pede
/// confirmação — isso é do chamador, em [onRemove].
class MaterialAddTrailing extends StatelessWidget {
  const MaterialAddTrailing({
    required this.isAdded,
    required this.isAdding,
    required this.onAdd,
    required this.onRemove,
    required this.removeTooltip,
    super.key,
  });

  final bool isAdded;

  /// Escrita em voo (adição ou remoção): vira spinner.
  final bool isAdding;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  /// Tooltip do `×` (`l10n.materialRemoveTooltip`).
  final String removeTooltip;

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
      return Tooltip(
        message: removeTooltip,
        child: CircleActionButton(
          icon: Icons.close,
          onPressed: onRemove,
          backgroundColor: AppColors.offlineMissing,
          iconColor: AppColors.textLight,
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
///
/// Não pré-julga o storage no toque (A8): a decisão é do editor, e só
/// [AddToActiveOutcome.storageUnavailable] — o desfecho real da escrita —
/// vira a snackbar de storage. Um `isarAvailableProvider` lido aqui
/// colapsaria «ainda abrindo» em «indisponível».
Future<void> addMaterialToActivePlaylist({
  required BuildContext context,
  required WidgetRef ref,
  required CatalogMaterial material,
  bool allowDuplicate = false,
}) async {
  final l10n = AppLocalizations.of(context)!;

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
