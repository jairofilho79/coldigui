import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../carousel/presentation/widgets/carousel_louvor_chip.dart';
import '../../../playlists/presentation/providers/playlists_provider.dart';
import '../../domain/entities/catalog_material.dart';

/// Só PDF e áudio entram numa lista — cifra e YouTube não têm entrada própria.
bool canAddMaterialToPlaylist(CatalogMaterial material) {
  return material is PdfMaterial || material is AudioMaterial;
}

/// Trailing `+` / spinner / ✓ de uma linha do sheet de materiais.
///
/// Extraído sem mudanças dos dois sheets antigos (era `_MaterialAddTrailing`,
/// duplicado verbatim em `louvor_material_sheet.dart` e
/// `coldigom_material_sheet.dart`).
class MaterialAddTrailing extends StatelessWidget {
  const MaterialAddTrailing({
    required this.isAdded,
    required this.isAdding,
    required this.onAdd,
    super.key,
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

/// Adiciona [material] à lista ativa e mostra a snackbar do resultado.
///
/// Mesmos providers e chaves l10n que os handlers do `LouvorGroupCard`
/// (`_handleAddMaterialToCarousel` / `_handleAddAudioToPlaylist`), que só
/// existiam para ser repassados aos sheets.
Future<void> addMaterialToActivePlaylist({
  required BuildContext context,
  required WidgetRef ref,
  required CatalogMaterial material,
}) async {
  final l10n = AppLocalizations.of(context)!;

  if (!ref.read(isarAvailableProvider)) {
    if (context.mounted) {
      showAppSnackbar(context, l10n.playlistStorageUnavailable);
    }
    return;
  }

  final playlists = ref.read(playlistsProvider.notifier);
  final added = switch (material) {
    PdfMaterial(:final louvor) => await playlists.addLouvorToActivePlaylist(
      louvor.pdfId,
    ),
    AudioMaterial(:final track) => await playlists.addAudioToActivePlaylist(
      track.audioId,
    ),
    // canAddMaterialToPlaylist barra os outros antes de chegar aqui.
    ChordMaterialRef() || YoutubeMaterialRef() => null,
  };
  if (added == null) return;

  if (!context.mounted) return;
  showAppSnackbar(
    context,
    added ? l10n.carouselAdded : l10n.carouselAlreadyAdded,
  );
}
