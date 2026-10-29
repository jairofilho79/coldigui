import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';

/// Botão "X" no trailing do chip — remove a entrada (modal de seleção,
/// [PlaylistListTile]).
///
/// Extraído de `carousel_louvor_chip.dart` (E4) — sem mudança de
/// comportamento.
class ChipRemoveButton extends StatelessWidget {
  const ChipRemoveButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CircleActionButton(icon: Icons.close, onPressed: onPressed);
  }
}

/// Botão "+" no trailing do chip — delega para [CarouselLouvorAddButton].
///
/// Extraído de `carousel_louvor_chip.dart` (E4) — sem mudança de
/// comportamento.
class ChipAddButton extends StatelessWidget {
  const ChipAddButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CarouselLouvorAddButton(onPressed: onPressed);
  }
}

/// Botão "+" circular — chip vermelho e sheet de materiais agrupados.
class CarouselLouvorAddButton extends StatelessWidget {
  const CarouselLouvorAddButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CircleActionButton(icon: Icons.add, onPressed: onPressed);
  }
}

/// Indicador de "já adicionado" no trailing do chip (check dentro de
/// círculo).
///
/// Extraído de `carousel_louvor_chip.dart` (E4) — sem mudança de
/// comportamento.
class ChipAddedIndicator extends StatelessWidget {
  const ChipAddedIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.textLight.withValues(alpha: 0.85),
          width: 1.5,
        ),
      ),
      child: const SizedBox(
        width: 24,
        height: 24,
        child: Icon(Icons.check, size: 16, color: AppColors.textLight),
      ),
    );
  }
}

/// Botão de ação circular — base de [ChipRemoveButton] e
/// [CarouselLouvorAddButton].
///
/// Extraído de `carousel_louvor_chip.dart` (E4) — sem mudança de
/// comportamento.
class CircleActionButton extends StatelessWidget {
  const CircleActionButton({
    required this.icon,
    required this.onPressed,
    this.backgroundColor = AppColors.textLight,
    this.iconColor = AppColors.title,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;

  /// Fundo do círculo — branco por padrão ([ChipRemoveButton],
  /// [CarouselLouvorAddButton]).
  final Color backgroundColor;

  /// Cor do ícone — vinho por padrão.
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AppColors.shadowMd,
      ),
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.gold, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          splashColor: AppColors.gold.withValues(alpha: 0.25),
          highlightColor: AppColors.gold.withValues(alpha: 0.12),
          child: SizedBox(
            width: 24,
            height: 24,
            child: Icon(icon, size: 16, color: iconColor),
          ),
        ),
      ),
    );
  }
}
