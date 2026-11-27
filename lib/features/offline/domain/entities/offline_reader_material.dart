import '../../../../core/utils/material_id_kind.dart';

/// Identidade e chave de armazenamento do material aberto no leitor.
/// Para letras, ambos identificam o louvor no catálogo local.
typedef OfflineReaderMaterial = ({MaterialKind kind, String id, String key});
