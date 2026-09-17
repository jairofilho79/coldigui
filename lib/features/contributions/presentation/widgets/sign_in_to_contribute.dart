import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/widgets/google_sign_in_button.dart';

/// Convite para entrar — mesmo molde do `_signedOut` de
/// `FavoriteMaterialKindsScreen`: a contribuição é presa à conta Google.
class SignInToContribute extends StatelessWidget {
  const SignInToContribute({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.contributeSignInPrompt,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textLight),
          ),
          const SizedBox(height: 16),
          const GoogleSignInButton(),
        ],
      ),
    );
  }
}
