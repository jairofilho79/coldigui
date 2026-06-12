import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';

/// Card informativo para a tela Sobre — título serif, divisor dourado e corpo sans.
///
/// Visual: fundo [AppColors.card], borda [AppColors.background], sombra
/// [AppColors.shadowMd], divisor [AppColors.gold] entre título e corpo.
///
/// Tipografia: título EB Garamond 18px [AppColors.title]; corpo Open Sans 14px
/// height 1.5 [AppColors.textDark].
///
/// Consumidores: [AboutScreen] (seções "Quem somos" e "Objetivo").
class AboutInfoCard extends StatelessWidget {
  const AboutInfoCard({
    required this.title,
    required this.paragraphs,
    super.key,
  });

  /// Título da seção (serif, [AppColors.title]).
  final String title;

  /// Parágrafos do corpo; renderizados em sequência com espaçamento vertical.
  final List<String> paragraphs;

  static const TextStyle _titleStyle = TextStyle(
    fontFamily: AppTypography.garamondFamily,
    fontWeight: FontWeight.w700,
    fontSize: 18,
    letterSpacing: 0.3,
    color: AppColors.title,
  );

  static const TextStyle _bodyStyle = TextStyle(
    fontFamily: AppTypography.sansFamily,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.5,
    color: AppColors.textDark,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.background, width: 1.5),
        boxShadow: AppColors.shadowMd,
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _titleStyle),
          const SizedBox(height: 10),
          const Divider(
            height: 1,
            thickness: 1.5,
            color: AppColors.gold,
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < paragraphs.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Text(paragraphs[i], style: _bodyStyle),
          ],
        ],
      ),
    );
  }
}
