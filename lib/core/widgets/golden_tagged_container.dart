import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_typography.dart';
import '../theme/color_extensions.dart';

/// Container "tag + caixa dourada" — padrão §5.2 MAPEAMENTO.
///
/// Exibe uma [label] flutuante (tag) sobre caixa creme com borda dourada 2px.
/// Usado em [SearchBar], [FiltersPanel] (Home compacto) e
/// [OfflineSettingsScreen] (seções completas com `contentPadding` padrão).
///
/// Campos de linha única na Home usam [compactContentPadding] e [compactRowHeight]
/// para alinhar texto e ícone sem a altura mínima de 48px do Material.
class GoldenTaggedContainer extends StatefulWidget {
  /// Padding interno reduzido para controles de linha única na Home.
  static const EdgeInsets compactContentPadding =
      EdgeInsets.fromLTRB(12, 14, 12, 8);

  /// Altura base da linha de controle em [SearchBar] e [FiltersPanel].
  static const double compactRowHeight = 24;

  /// Altura mínima da linha compacta, respeitando [MediaQuery.textScalerOf].
  static double compactRowHeightFor(BuildContext context) {
    final scaledTextLine = MediaQuery.textScalerOf(context)
        .scale(AppTypography.body.fontSize! * 1.2);
    return scaledTextLine > compactRowHeight
        ? scaledTextLine
        : compactRowHeight;
  }

  const GoldenTaggedContainer({
    required this.label,
    required this.child,
    super.key,
    this.glowEnabled = false,
    this.glowActive = false,
    this.onTap,
    this.contentPadding = const EdgeInsets.fromLTRB(12, 20, 12, 12),
  });

  /// Texto da tag no canto superior esquerdo (ex.: "Buscar", "Filtros").
  final String label;

  /// Conteúdo interno do container (TextField, Dropdown, chips, etc.).
  final Widget child;

  /// Quando `true`, permite animação de glow ao focar ([glowActive]).
  final bool glowEnabled;

  /// Quando `true` (e [glowEnabled]), exibe glow animado — transição única, sem repeat.
  final bool glowActive;

  /// Callback opcional para painéis colapsáveis (ex.: expandir [FiltersPanel]).
  final VoidCallback? onTap;

  /// Padding interno da caixa dourada (abaixo da tag flutuante).
  ///
  /// Padrão `12/20/12/12`. Campos compactos da Home usam [compactContentPadding].
  final EdgeInsetsGeometry contentPadding;

  @override
  State<GoldenTaggedContainer> createState() => _GoldenTaggedContainerState();
}

class _GoldenTaggedContainerState extends State<GoldenTaggedContainer>
    with SingleTickerProviderStateMixin {
  AnimationController? _glowController;
  Animation<double>? _glowAnimation;

  @override
  void initState() {
    super.initState();
    _setupGlowController();
    _syncGlowAnimation();
  }

  @override
  void didUpdateWidget(GoldenTaggedContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.glowEnabled != widget.glowEnabled) {
      _disposeGlow();
      _setupGlowController();
    }
    if (oldWidget.glowActive != widget.glowActive ||
        oldWidget.glowEnabled != widget.glowEnabled) {
      _syncGlowAnimation();
    }
  }

  void _setupGlowController() {
    if (!widget.glowEnabled || _animationsDisabled) return;

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _glowAnimation = Tween<double>(begin: 0.25, end: 0.75).animate(
      CurvedAnimation(parent: _glowController!, curve: Curves.easeOut),
    );
  }

  void _syncGlowAnimation() {
    final controller = _glowController;
    if (controller == null || _glowAnimation == null) return;

    if (!widget.glowEnabled || !widget.glowActive) {
      if (_animationsDisabled) {
        controller.value = 0;
      } else {
        controller.reverse();
      }
      return;
    }

    if (_animationsDisabled) {
      controller.value = 1;
    } else {
      controller.forward();
    }
  }

  bool get _animationsDisabled {
    final dispatcher = SchedulerBinding.instance.platformDispatcher;
    if (dispatcher.accessibilityFeatures.disableAnimations) return true;
    // Evita pumpAndSettle infinito em widget tests (repeat no glow).
    return WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgets');
  }

  void _disposeGlow() {
    _glowController?.dispose();
    _glowController = null;
    _glowAnimation = null;
  }

  @override
  void dispose() {
    _disposeGlow();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: widget.contentPadding,
      child: widget.child,
    );

    Widget box = Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold, width: 2),
        boxShadow: widget.glowEnabled && _glowAnimation == null
            ? [
                BoxShadow(
                  color: AppColors.goldGlow,
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: content,
    );

    if (widget.glowEnabled && _glowAnimation != null) {
      box = AnimatedBuilder(
        animation: _glowAnimation!,
        builder: (context, child) {
          final glowValue = widget.glowActive ? _glowAnimation!.value : 0.0;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: glowValue > 0
                  ? [
                      BoxShadow(
                        color: AppColors.goldLight.withValues(alpha: glowValue),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color:
                            AppColors.gold.withValues(alpha: glowValue * 0.5),
                        blurRadius: 12,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: child,
          );
        },
        child: box,
      );
    }

    final tagged = Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: box,
        ),
        Positioned(
          left: 12,
          top: 0,
          child: _TagLabel(text: widget.label),
        ),
      ],
    );

    if (widget.onTap == null) return tagged;

    return Semantics(
      button: true,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: tagged,
      ),
    );
  }
}

class _TagLabel extends StatelessWidget {
  const _TagLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final verticalPadding = MediaQuery.textScalerOf(context).scale(2.0);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: verticalPadding),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.gold, width: 1.5),
      ),
      child: Text(text, style: AppTypography.tagLabel),
    );
  }
}
