import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/presentation/widgets/material_sheet_actions.dart';

/// Material preferido para o "+" sempre visível do card (C5).
///
/// Ordem: PDF principal ([LouvorGroup.primaryLouvor]) se existir; senão o
/// único áudio do grupo; senão o primeiro extra que
/// [canAddMaterialToPlaylist] aceita (cifra/YouTube não têm entrada própria na
/// lista ativa). `null` quando nada do grupo é adicionável — ex.: só YouTube.
CatalogMaterial? preferredMaterialForGroup(LouvorGroup group) {
  final primary = group.primaryLouvor;
  if (primary != null) return PdfMaterial(primary);

  final audioTracks = group.audioTracks;
  if (audioTracks.length == 1) return AudioMaterial(audioTracks.first);

  for (final material in group.extras) {
    if (canAddMaterialToPlaylist(material)) return material;
  }
  return null;
}
