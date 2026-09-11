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
    super.key,
  });

  final BorderRadius borderRadius;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: borderRadius, child: child),
    );
  }
}
