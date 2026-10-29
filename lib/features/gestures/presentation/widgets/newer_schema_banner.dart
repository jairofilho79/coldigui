import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';

/// Aviso acima do papel quando `schemaMajor > 1`: o app tenta renderizar
/// mesmo assim, mas o regente precisa saber por que algo pode faltar.
class NewerSchemaBanner extends StatelessWidget {
  const NewerSchemaBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MaterialBanner(
      backgroundColor: AppColors.card,
      leading: const Icon(Icons.system_update_alt, color: AppColors.title),
      content: Text(
        l10n.gesturesNewerSchemaWarning,
        style: AppTypography.label.copyWith(color: AppColors.textDark),
      ),
      actions: const [SizedBox.shrink()],
    );
  }
}
