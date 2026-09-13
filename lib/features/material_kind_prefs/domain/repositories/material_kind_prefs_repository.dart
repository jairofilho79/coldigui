import '../entities/material_kind_prefs.dart';

/// Persistência local do documento de favoritos, por conta (`sub` Google).
abstract class MaterialKindPrefsRepository {
  /// `null` quando a conta nunca salvou neste aparelho.
  Future<MaterialKindPrefs?> read(String sub);

  Future<void> write(String sub, MaterialKindPrefs prefs);
}
