import 'package:coldigui/features/material_kind_prefs/domain/entities/material_kind_prefs.dart';
import 'package:coldigui/features/material_kind_prefs/presentation/providers/material_kind_prefs_provider.dart';

/// Favoritos fixos, sem sessão nem SharedPreferences — [MaterialKindPrefs.empty]
/// faz as vezes de «deslogado».
class FixedMaterialKindPrefsNotifier extends MaterialKindPrefsNotifier {
  FixedMaterialKindPrefsNotifier(this.value);

  final MaterialKindPrefs value;

  @override
  Future<MaterialKindPrefs> build() async => value;
}
