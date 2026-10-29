import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/tutorial/presentation/providers/tutorial_provider.dart';
import '../../../../l10n/app_localizations.dart';

/// Categorias dos atalhos de teclado da aplicação.
enum ShortcutCategory {
  navigation,
  repertoireAudio,
  sheetMusic,
  chordsGestures;

  String localizedLabel(AppLocalizations l10n) => switch (this) {
    ShortcutCategory.navigation => l10n.shortcutCatNavigation,
    ShortcutCategory.repertoireAudio => l10n.shortcutCatRepertoireAudio,
    ShortcutCategory.sheetMusic => l10n.shortcutCatSheetMusic,
    ShortcutCategory.chordsGestures => l10n.shortcutCatChordsGestures,
  };
}

/// Representa um atalho de teclado com suas teclas, descrição e contexto.
class AppShortcutItem {
  const AppShortcutItem({
    required this.category,
    required this.keys,
    required this.action,
    this.contextBadge,
  });

  final ShortcutCategory category;

  /// Lista de alternativas de combinação de teclas.
  /// Cada elemento interno representa uma combinação simultânea (ex.: `['Ctrl', 'K']`).
  final List<List<String>> keys;

  /// Descrição da ação executada pelo atalho.
  final String action;

  /// Chip opcional de contexto (ex.: "Leitor", "PDF", "Cifras").
  final String? contextBadge;
}

/// Cria a lista de atalhos localizada no idioma atual.
List<AppShortcutItem> buildAppShortcutsList(AppLocalizations l10n) => [
  // Navegação & Busca
  AppShortcutItem(
    category: ShortcutCategory.navigation,
    keys: const [
      ['Ctrl', 'K'],
      ['Cmd', 'K'],
      ['/'],
    ],
    action: l10n.shortcutActionHomeSearch,
  ),
  AppShortcutItem(
    category: ShortcutCategory.navigation,
    keys: const [
      ['?'],
    ],
    action: l10n.shortcutActionOpenShortcuts,
  ),
  AppShortcutItem(
    category: ShortcutCategory.navigation,
    keys: const [
      ['Esc'],
    ],
    action: l10n.shortcutActionEscape,
  ),

  // Repertório & Áudio
  AppShortcutItem(
    category: ShortcutCategory.repertoireAudio,
    keys: const [
      ['N'],
    ],
    action: l10n.shortcutActionNextPraise,
    contextBadge: l10n.shortcutBadgeReader,
  ),
  AppShortcutItem(
    category: ShortcutCategory.repertoireAudio,
    keys: const [
      ['P'],
    ],
    action: l10n.shortcutActionPreviousPraise,
    contextBadge: l10n.shortcutBadgeReader,
  ),
  AppShortcutItem(
    category: ShortcutCategory.repertoireAudio,
    keys: const [
      ['Ctrl', '→'],
      ['Ctrl', '←'],
    ],
    action: l10n.shortcutActionCarouselQueue,
  ),
  AppShortcutItem(
    category: ShortcutCategory.repertoireAudio,
    keys: const [
      ['Espaço'],
    ],
    action: l10n.shortcutActionToggleAudio,
    contextBadge: l10n.shortcutBadgeGeneral,
  ),
  AppShortcutItem(
    category: ShortcutCategory.repertoireAudio,
    keys: const [
      ['Ctrl', 'Espaço'],
      ['Cmd', 'Espaço'],
    ],
    action: l10n.shortcutActionToggleAudioPdf,
    contextBadge: l10n.shortcutBadgeReaderPdf,
  ),
  AppShortcutItem(
    category: ShortcutCategory.repertoireAudio,
    keys: const [
      ['J'],
    ],
    action: l10n.shortcutActionSeekAudioBack,
  ),
  AppShortcutItem(
    category: ShortcutCategory.repertoireAudio,
    keys: const [
      ['L'],
    ],
    action: l10n.shortcutActionSeekAudioForward,
  ),

  // Partituras (PDF)
  AppShortcutItem(
    category: ShortcutCategory.sheetMusic,
    keys: const [
      ['F'],
    ],
    action: l10n.shortcutActionToggleFullscreen,
    contextBadge: l10n.shortcutBadgeReader,
  ),
  AppShortcutItem(
    category: ShortcutCategory.sheetMusic,
    keys: const [
      ['Espaço'],
      ['PageDown'],
      ['↓'],
      ['→'],
    ],
    action: l10n.shortcutActionNextPagePdf,
  ),
  AppShortcutItem(
    category: ShortcutCategory.sheetMusic,
    keys: const [
      ['PageUp'],
      ['↑'],
      ['←'],
    ],
    action: l10n.shortcutActionPrevPagePdf,
  ),
  AppShortcutItem(
    category: ShortcutCategory.sheetMusic,
    keys: const [
      ['Home'],
    ],
    action: l10n.shortcutActionFirstPagePdf,
  ),
  AppShortcutItem(
    category: ShortcutCategory.sheetMusic,
    keys: const [
      ['End'],
    ],
    action: l10n.shortcutActionLastPagePdf,
  ),
  AppShortcutItem(
    category: ShortcutCategory.sheetMusic,
    keys: const [
      ['Z'],
    ],
    action: l10n.shortcutActionFitModePdf,
  ),
  AppShortcutItem(
    category: ShortcutCategory.sheetMusic,
    keys: const [
      ['G'],
    ],
    action: l10n.shortcutActionPageGridPdf,
  ),

  // Cifras & Gestos
  AppShortcutItem(
    category: ShortcutCategory.chordsGestures,
    keys: const [
      ['S'],
    ],
    action: l10n.shortcutActionToggleAutoscroll,
    contextBadge: l10n.shortcutBadgeChordsLyrics,
  ),
  AppShortcutItem(
    category: ShortcutCategory.chordsGestures,
    keys: const [
      ['['],
      [']'],
    ],
    action: l10n.shortcutActionAdjustAutoscrollSpeed,
    contextBadge: l10n.shortcutBadgeAutoscroll,
  ),
  AppShortcutItem(
    category: ShortcutCategory.chordsGestures,
    keys: const [
      ['+'],
      ['-'],
    ],
    action: l10n.shortcutActionTransposePitch,
    contextBadge: l10n.shortcutBadgeChords,
  ),
  AppShortcutItem(
    category: ShortcutCategory.chordsGestures,
    keys: const [
      ['→'],
      ['←'],
    ],
    action: l10n.shortcutActionNextGesture,
    contextBadge: l10n.shortcutBadgeFocusModeCias,
  ),
];

/// Exibe o diálogo da Central de Atalhos de Teclado.
Future<void> showAppShortcutsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => const AppShortcutsDialog(),
  );
}

/// Diálogo central com catálogo de atalhos de teclado para desktop/web.
class AppShortcutsDialog extends StatefulWidget {
  const AppShortcutsDialog({super.key});

  @override
  State<AppShortcutsDialog> createState() => _AppShortcutsDialogState();
}

class _AppShortcutsDialogState extends State<AppShortcutsDialog> {
  final _portalController = SpotlightGuidePortalController();
  TutorialController? _tutorialController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tutorialController == null) {
      try {
        _tutorialController = ProviderScope.containerOf(
          context,
          listen: false,
        ).read(tutorialControllerProvider);
        _tutorialController?.pushPortalController(_portalController);
      } catch (_) {
        _tutorialController = null;
      }
    }
  }

  @override
  void dispose() {
    try {
      if (_portalController.isShowing) {
        _portalController.hide();
      }
      _tutorialController?.popPortalController(_portalController);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shortcuts = buildAppShortcutsList(l10n);

    return SpotlightGuidePortal(
      controller: _portalController,
      autoStart: false,
      missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
      barrier: const SpotlightGuideBarrierStyle(
        color: Color(0x99000000),
        blurSigma: 0,
      ),
      barrierDismissBehavior: SpotlightGuideDismissBehavior.anytime,
      onBarrierTap: (c) => _tutorialController?.hide(),
      onFinish: () => _tutorialController?.resetTutorialState(),
      child: Dialog(
        backgroundColor: AppColors.background,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 680,
            maxHeight: 520,
          ),
          child: SizedBox(
            height: 500,
            child: DefaultTabController(
              length: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.btnBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.gold, width: 1.2),
                          ),
                          child: const Icon(
                            Icons.keyboard_outlined,
                            color: AppColors.goldLight,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.shortcutsTitle,
                                style: const TextStyle(
                                  fontFamily: AppTypography.garamondFamily,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                  letterSpacing: 0.5,
                                  color: AppColors.placeholder,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.shortcutsSubtitle,
                                style: const TextStyle(
                                  fontFamily: AppTypography.sansFamily,
                                  fontSize: 12,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SpotlightGuideTarget(
                          id: 'shortcuts-info-button',
                          child: IconButton(
                            icon: const Icon(Icons.info_outline, color: AppColors.placeholder),
                            tooltip: l10n.tutorialTooltipHowToUseShortcuts,
                            onPressed: () => _tutorialController
                                ?.startAppShortcutsTutorial(context),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.placeholder),
                          tooltip: l10n.close,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: AppColors.gold, height: 1, thickness: 1),

                  // Abas de categorias
                  SpotlightGuideTarget(
                    id: 'shortcuts-categories-tabs',
                    child: Container(
                      color: AppColors.btnBackground.withValues(alpha: 0.5),
                      child: TabBar(
                        isScrollable: true,
                        labelColor: AppColors.goldLight,
                        unselectedLabelColor: AppColors.textLight,
                        indicatorColor: AppColors.gold,
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(
                          fontFamily: AppTypography.sansFamily,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontFamily: AppTypography.sansFamily,
                          fontWeight: FontWeight.w400,
                          fontSize: 13,
                        ),
                        tabs: [
                          Tab(text: l10n.shortcutsTabAll),
                          Tab(text: l10n.shortcutsTabNavigation),
                          Tab(text: l10n.shortcutsTabRepertoireAudio),
                          Tab(text: l10n.shortcutsTabSheetMusic),
                          Tab(text: l10n.shortcutsTabChordsGestures),
                        ],
                      ),
                    ),
                  ),

                  // Conteúdo scrollável com atalhos
                  Expanded(
                    child: SpotlightGuideTarget(
                      id: 'shortcuts-list-items',
                      child: TabBarView(
                        children: [
                          _ShortcutList(items: shortcuts),
                          _ShortcutList(
                            items: shortcuts
                                .where((item) =>
                                    item.category == ShortcutCategory.navigation)
                                .toList(),
                          ),
                          _ShortcutList(
                            items: shortcuts
                                .where((item) =>
                                    item.category == ShortcutCategory.repertoireAudio)
                                .toList(),
                          ),
                          _ShortcutList(
                            items: shortcuts
                                .where((item) =>
                                    item.category == ShortcutCategory.sheetMusic)
                                .toList(),
                          ),
                          _ShortcutList(
                            items: shortcuts
                                .where((item) =>
                                    item.category == ShortcutCategory.chordsGestures)
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Rodapé com dica rápida
                  SpotlightGuideTarget(
                    id: 'shortcuts-footer-tip',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: const BoxDecoration(
                        color: AppColors.btnBackground,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.tips_and_updates_outlined,
                            color: AppColors.gold,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.shortcutsFooterTip,
                              style: const TextStyle(
                                fontFamily: AppTypography.sansFamily,
                                fontSize: 12,
                                color: AppColors.textLight,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.goldLight,
                            ),
                            child: Text(l10n.shortcutsGotIt),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutList extends StatelessWidget {
  const _ShortcutList({required this.items});

  final List<AppShortcutItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (items.isEmpty) {
      return Center(
        child: Text(
          l10n?.shortcutsEmpty ?? 'Nenhum atalho encontrado.',
          style: const TextStyle(color: AppColors.textLight),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      separatorBuilder: (_, _) => Divider(
        color: AppColors.gold.withValues(alpha: 0.2),
        height: 1,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge de teclas
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 140),
                child: _KeyCombosView(keys: item.keys),
              ),
              const SizedBox(width: 16),

              // Descrição
              Expanded(
                child: Text(
                  item.action,
                  style: const TextStyle(
                    fontFamily: AppTypography.sansFamily,
                    fontSize: 13,
                    color: AppColors.textLight,
                    height: 1.3,
                  ),
                ),
              ),

              // Badge de contexto (se houver)
              if (item.contextBadge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gold, width: 1),
                  ),
                  child: Text(
                    item.contextBadge!,
                    style: const TextStyle(
                      fontFamily: AppTypography.sansFamily,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: AppColors.title,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _KeyCombosView extends StatelessWidget {
  const _KeyCombosView({required this.keys});

  final List<List<String>> keys;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final orText = l10n?.shortcutsOr ?? 'ou';
    final comboWidgets = <Widget>[];

    for (var i = 0; i < keys.length; i++) {
      if (i > 0) {
        comboWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              orText,
              style: const TextStyle(
                fontFamily: AppTypography.sansFamily,
                fontSize: 11,
                color: AppColors.placeholder,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
      }

      final singleCombo = keys[i];
      final keyBadges = <Widget>[];

      for (var j = 0; j < singleCombo.length; j++) {
        if (j > 0) {
          keyBadges.add(
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                '+',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppColors.goldLight,
                ),
              ),
            ),
          );
        }
        keyBadges.add(ShortcutKeyBadge(label: singleCombo[j]));
      }

      comboWidgets.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: keyBadges,
      ));
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: comboWidgets,
    );
  }
}

/// Badge visual representando uma tecla física (<kbd>).
class ShortcutKeyBadge extends StatelessWidget {
  const ShortcutKeyBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.btnBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.gold, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 2,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppTypography.sansFamily,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: AppColors.textLight,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
