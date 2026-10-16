import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/tutorial/presentation/providers/tutorial_provider.dart';

/// Categorias dos atalhos de teclado da aplicação.
enum ShortcutCategory {
  navigation('Navegação & Busca'),
  repertoireAudio('Repertório & Áudio'),
  sheetMusic('Partituras (PDF)'),
  chordsGestures('Cifras & Gestos');

  const ShortcutCategory(this.label);
  final String label;
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

/// Lista completa dos atalhos suportados no Coldigui.
const appShortcutsList = <AppShortcutItem>[
  // Navegação & Busca
  AppShortcutItem(
    category: ShortcutCategory.navigation,
    keys: [
      ['Ctrl', 'K'],
      ['Cmd', 'K'],
      ['/'],
    ],
    action: 'Ir para a Home e focar campo de busca',
  ),
  AppShortcutItem(
    category: ShortcutCategory.navigation,
    keys: [
      ['?'],
    ],
    action: 'Abrir esta Central de Atalhos de Teclado',
  ),
  AppShortcutItem(
    category: ShortcutCategory.navigation,
    keys: [
      ['Esc'],
    ],
    action: 'Sair de tela cheia, limpar busca ou fechar janelas',
  ),

  // Repertório & Áudio
  AppShortcutItem(
    category: ShortcutCategory.repertoireAudio,
    keys: [
      ['N'],
    ],
    action: 'Avançar para o próximo louvor do repertório',
    contextBadge: 'Leitor',
  ),
  AppShortcutItem(
    category: ShortcutCategory.repertoireAudio,
    keys: [
      ['P'],
    ],
    action: 'Voltar para o louvor anterior do repertório',
    contextBadge: 'Leitor',
  ),
  AppShortcutItem(
    category: ShortcutCategory.repertoireAudio,
    keys: [
      ['Ctrl', '→'],
      ['Ctrl', '←'],
    ],
    action: 'Navegar pela fila do carrossel de louvores',
  ),
  AppShortcutItem(
    category: ShortcutCategory.repertoireAudio,
    keys: [
      ['Espaço'],
    ],
    action: 'Tocar ou pausar o áudio do louvor',
    contextBadge: 'Geral',
  ),
  AppShortcutItem(
    category: ShortcutCategory.repertoireAudio,
    keys: [
      ['Ctrl', 'Espaço'],
      ['Cmd', 'Espaço'],
    ],
    action: 'Tocar ou pausar áudio mesmo com partitura aberta',
    contextBadge: 'Leitor PDF',
  ),
  AppShortcutItem(
    category: ShortcutCategory.repertoireAudio,
    keys: [
      ['J'],
    ],
    action: 'Voltar 10 segundos no áudio',
  ),
  AppShortcutItem(
    category: ShortcutCategory.repertoireAudio,
    keys: [
      ['L'],
    ],
    action: 'Avançar 10 segundos no áudio',
  ),

  // Partituras (PDF)
  AppShortcutItem(
    category: ShortcutCategory.sheetMusic,
    keys: [
      ['F'],
    ],
    action: 'Alternar modo de tela cheia',
    contextBadge: 'Leitor',
  ),
  AppShortcutItem(
    category: ShortcutCategory.sheetMusic,
    keys: [
      ['Espaço'],
      ['PageDown'],
      ['↓'],
      ['→'],
    ],
    action: 'Avançar página ou rolar partitura',
  ),
  AppShortcutItem(
    category: ShortcutCategory.sheetMusic,
    keys: [
      ['PageUp'],
      ['↑'],
      ['←'],
    ],
    action: 'Voltar página da partitura',
  ),
  AppShortcutItem(
    category: ShortcutCategory.sheetMusic,
    keys: [
      ['Home'],
    ],
    action: 'Ir para a primeira página',
  ),
  AppShortcutItem(
    category: ShortcutCategory.sheetMusic,
    keys: [
      ['End'],
    ],
    action: 'Ir para a última página',
  ),
  AppShortcutItem(
    category: ShortcutCategory.sheetMusic,
    keys: [
      ['Z'],
    ],
    action: 'Alternar modo de ajuste (largura / altura)',
  ),
  AppShortcutItem(
    category: ShortcutCategory.sheetMusic,
    keys: [
      ['G'],
    ],
    action: 'Abrir seletor rápido de páginas em grade',
  ),

  // Cifras & Gestos
  AppShortcutItem(
    category: ShortcutCategory.chordsGestures,
    keys: [
      ['S'],
    ],
    action: 'Ligar ou desligar rolagem automática (autoscroll)',
    contextBadge: 'Cifras/Letras',
  ),
  AppShortcutItem(
    category: ShortcutCategory.chordsGestures,
    keys: [
      ['['],
      [']'],
    ],
    action: 'Diminuir ou aumentar velocidade de rolagem',
    contextBadge: 'Autoscroll',
  ),
  AppShortcutItem(
    category: ShortcutCategory.chordsGestures,
    keys: [
      ['+'],
      ['-'],
    ],
    action: 'Transpor tom do louvor (+1 / -1 semitom)',
    contextBadge: 'Cifras',
  ),
  AppShortcutItem(
    category: ShortcutCategory.chordsGestures,
    keys: [
      ['→'],
      ['←'],
    ],
    action: 'Próximo gesto ou gesto anterior na regência',
    contextBadge: 'Modo Foco CIAs',
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
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Atalhos de Teclado',
                                style: TextStyle(
                                  fontFamily: AppTypography.garamondFamily,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                  letterSpacing: 0.5,
                                  color: AppColors.placeholder,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Comandos rápidos de produtividade para Desktop e Web',
                                style: TextStyle(
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
                            tooltip: 'Como usar os atalhos',
                            onPressed: () => _tutorialController
                                ?.startAppShortcutsTutorial(context),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.placeholder),
                          tooltip: 'Fechar',
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
                      color: AppColors.btnBackground.withOpacity(0.5),
                      child: const TabBar(
                        isScrollable: true,
                        labelColor: AppColors.goldLight,
                        unselectedLabelColor: AppColors.textLight,
                        indicatorColor: AppColors.gold,
                        indicatorWeight: 3,
                        labelStyle: TextStyle(
                          fontFamily: AppTypography.sansFamily,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        unselectedLabelStyle: TextStyle(
                          fontFamily: AppTypography.sansFamily,
                          fontWeight: FontWeight.w400,
                          fontSize: 13,
                        ),
                        tabs: [
                          Tab(text: 'Todos'),
                          Tab(text: 'Navegação'),
                          Tab(text: 'Repertório & Áudio'),
                          Tab(text: 'Partituras'),
                          Tab(text: 'Cifras & Gestos'),
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
                          _ShortcutList(items: appShortcutsList),
                          _ShortcutList(
                            items: appShortcutsList
                                .where((item) =>
                                    item.category == ShortcutCategory.navigation)
                                .toList(),
                          ),
                          _ShortcutList(
                            items: appShortcutsList
                                .where((item) =>
                                    item.category == ShortcutCategory.repertoireAudio)
                                .toList(),
                          ),
                          _ShortcutList(
                            items: appShortcutsList
                                .where((item) =>
                                    item.category == ShortcutCategory.sheetMusic)
                                .toList(),
                          ),
                          _ShortcutList(
                            items: appShortcutsList
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
                          const Expanded(
                            child: Text(
                              'Pressione ? em qualquer tela para abrir este painel a qualquer momento.',
                              style: TextStyle(
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
                            child: const Text('Entendi'),
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
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum atalho encontrado.',
          style: TextStyle(color: AppColors.textLight),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
        color: AppColors.gold.withOpacity(0.2),
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
    final comboWidgets = <Widget>[];

    for (var i = 0; i < keys.length; i++) {
      if (i > 0) {
        comboWidgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'ou',
              style: TextStyle(
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
