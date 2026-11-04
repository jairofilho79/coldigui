import '../../../../core/utils/material_id_kind.dart';

/// Chave sintética: a letra não tem UUID de material_kind no Coldigom.
const kLyricsFavoriteKindId = 'type:lyrics';

bool isFavoriteMaterialType(String type) {
  final normalized = type.toLowerCase();
  return normalized != 'youtube' &&
      normalized != 'audio' &&
      !kAudioMaterialExtensions.contains('.$normalized');
}

int favoriteMaterialTypeOrder(String type) => switch (type.toLowerCase()) {
  'pdf' => 0,
  'chord' => 1,
  'gestures' => 2,
  'lyrics' => 3,
  _ => 4,
};

String? favoriteMaterialKindId(MaterialKind type, String? kindId) {
  return switch (type) {
    MaterialKind.audio || MaterialKind.youtube => null,
    MaterialKind.lyrics => kLyricsFavoriteKindId,
    MaterialKind.gesture => kindId ?? 'type:gestures',
    _ => kindId ?? 'type:${type.name}',
  };
}
