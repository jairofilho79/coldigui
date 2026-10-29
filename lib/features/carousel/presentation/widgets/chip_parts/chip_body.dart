import 'package:flutter/material.dart';

/// Corpo do chip — envolve o [child] num [InkWell] quando há [onTap]; sem
/// [onTap], passa o [child] direto (sem feedback de toque).
///
/// Extraído de `carousel_louvor_chip.dart` (E4) — sem mudança de
/// comportamento.
class ChipBody extends StatelessWidget {
  const ChipBody({
    required this.borderRadius,
    required this.child,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final BorderRadius borderRadius;
  final Widget child;
  final VoidCallback? onTap;

  /// Pressionar e segurar o corpo do chip — ex.: abrir o material favorito
  /// do grupo direto no leitor (card multi-material na Pesquisar).
  ///
  /// Só tem efeito com [onTap] também presente — sem ele, o `InkWell` nem é
  /// criado (ver [build]), então [onLongPress] fica inerte mesmo não-nulo.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: borderRadius,
        child: child,
      ),
    );
  }
}
