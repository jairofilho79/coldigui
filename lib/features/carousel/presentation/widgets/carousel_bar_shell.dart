import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';

/// Container visual da barra de carousel (fundo creme, elevação leve).
///
/// Usado no [ShellScaffold] via [CarouselChips] (shell e `/leitor`).
///
/// [carouselBarShellHeight] — altura aproximada (padding + chip) para layout.
/// [carouselBarIconButtonStyle] — cor vinho PLPCG nos ícones da barra.
const carouselBarShellHeight = 60.0;

/// Gap horizontal entre itens da barra (tempos↔slider, seeker↔controles).
///
/// Igual ao padding lateral do shell e ao padding padrão dos [IconButton]
/// (Salvar / Compartilhar ficam colados; o ar entre glifos é ~2× este valor).
const carouselBarHorizontalGap = 8.0;

/// Estilo padrão dos [IconButton] da barra de carousel.
///
/// Consumido por [CarouselNavigatorBar] (setas, lista) e
/// [CarouselBarTrailingActions] (salvar/folheto/limpar em layout expandido).
///
/// Usa [AppColors.title] como `foregroundColor`. O estado desabilitado mantém
/// o mesmo matiz com opacidade reduzida — evita ícones pretos/cinza do tema
/// Material padrão sobre o fundo creme da barra.
ButtonStyle get carouselBarIconButtonStyle => IconButton.styleFrom(
  foregroundColor: AppColors.title,
  disabledForegroundColor: AppColors.title.withValues(alpha: 0.38),
);

class CarouselBarShell extends StatelessWidget {
  const CarouselBarShell({
    required this.child,
    this.applySafeArea = true,
    super.key,
  });

  final Widget child;

  /// Quando `true` (default), aplica `SafeArea(bottom: false)` no conteúdo.
  final bool applySafeArea;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(children: [Expanded(child: child)]),
    );

    return Material(
      elevation: 1,
      color: theme.colorScheme.surfaceContainerHighest,
      child: applySafeArea ? SafeArea(bottom: false, child: content) : content,
    );
  }
}
