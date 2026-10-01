import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';

/// Card retrátil "Precisa de ajuda?" com explicação simples da tela
/// e detalhamento de cada um dos casos de uso de contribuição.
class ContributeHelpCollapse extends StatefulWidget {
  const ContributeHelpCollapse({super.key});

  @override
  State<ContributeHelpCollapse> createState() => _ContributeHelpCollapseState();
}

class _ContributeHelpCollapseState extends State<ContributeHelpCollapse> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF381F1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.gold,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Precisa de ajuda?',
                      style: AppTypography.headline.copyWith(
                        color: AppColors.gold,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.gold,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(
                          color: Color(0x33D4AF37),
                          height: 1,
                          thickness: 1,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Esta página permite que você envie contribuições e nos ajude a aprimorar o aplicativo e o acervo do PLPCG. Escolha a opção que melhor descreve o seu caso:',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textLight.withValues(alpha: 0.9),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _HelpItem(
                          icon: Icons.bug_report_outlined,
                          title: l10n.contributeKindBug,
                          description:
                              'Problemas no app (travamento, tela preta, botões sem resposta ou falha no áudio/leitor). Se puder, anexe uma captura de tela.',
                        ),
                        const SizedBox(height: 10),
                        _HelpItem(
                          icon: Icons.edit_note_outlined,
                          title: l10n.contributeKindWrongInfo,
                          description:
                              'Dados incorretos em um louvor existente (número, tom, título, autor, ritmo ou louvor duplicado).',
                        ),
                        const SizedBox(height: 10),
                        _HelpItem(
                          icon: Icons.queue_music_outlined,
                          title: l10n.contributeKindContent,
                          description:
                              'Envio ou sugestão de novos materiais (cifras, partituras, áudios ou letras) ou melhoria em arquivo existente.',
                        ),
                        const SizedBox(height: 10),
                        _HelpItem(
                          icon: Icons.lightbulb_outline,
                          title: l10n.contributeKindImprovement,
                          description:
                              'Sugestões de novos recursos, mudanças no visual ou ideias para deixar o app mais prático nos ensaios e cultos.',
                        ),
                        const SizedBox(height: 10),
                        _HelpItem(
                          icon: Icons.help_outline,
                          title: l10n.contributeKindOther,
                          description:
                              'Dúvidas gerais, recados para a equipe ou qualquer outro assunto não listado acima.',
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('💡', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Você também pode anexar arquivos (até 32 MB) ou colar links do Google Drive e YouTube para enriquecer seu envio.',
                                  style: AppTypography.body.copyWith(
                                    color: AppColors.textLight
                                        .withValues(alpha: 0.85),
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  const _HelpItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.goldLight, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: AppTypography.body.copyWith(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textLight.withValues(alpha: 0.9),
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldLight,
                  ),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
