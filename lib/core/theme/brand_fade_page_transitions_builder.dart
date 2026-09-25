import 'package:flutter/material.dart';

import 'color_extensions.dart';

/// Um instante da transição — ver [BrandFadePageTransitionsBuilder.frameAt].
typedef BrandFadeFrame = ({double overlay, bool pageVisible, double scale});

/// Transição de página "passar pelo marrom": a rota nova cobre a de baixo
/// com [AppColors.background] e depois se revela, crescendo de
/// [kStartScale] a 100%.
///
/// Substitui o `FadeForwardsPageTransitionsBuilder`, que deslocava as duas
/// páginas 25% da largura (ícones "andando" durante o fade) e pintava o
/// creme do `ColorScheme.surface` entre elas.
///
/// Pensada para GPU fraca na web: a página nunca fica semitransparente —
/// só é pintada ou não ([Opacity] 0/1 não abre camada offscreen) — e o
/// esmaecer é um retângulo de cor sólida por cima. Escala é só transform.
///
/// Todo o efeito vive na rota de cima (`animation`); a de baixo fica
/// parada, e o pop roda a mesma curva ao contrário. Com "reduzir movimento"
/// ([MediaQuery.disableAnimationsOf]) a página aparece inteira de imediato.
class BrandFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const BrandFadePageTransitionsBuilder();

  /// Duração total (ida e volta).
  static const int kTransitionMilliseconds = 240;

  /// Fração da animação em que a cor cobre tudo e a página nova passa a
  /// ser pintada — antes, só a cor subindo; depois, a página se revelando.
  static const double kMidpoint = 0.4;

  /// Escala da página nova quando começa a aparecer.
  static const double kStartScale = 0.98;

  @override
  Duration get transitionDuration =>
      const Duration(milliseconds: kTransitionMilliseconds);

  /// Estado visual em [t] (valor linear 0–1 da animação da rota).
  static BrandFadeFrame frameAt(double t) {
    if (t < kMidpoint) {
      return (
        overlay: Curves.easeOut.transform(t / kMidpoint),
        pageVisible: false,
        scale: kStartScale,
      );
    }
    final p = (t - kMidpoint) / (1 - kMidpoint);
    return (
      overlay: 1 - Curves.easeOut.transform(p),
      pageVisible: true,
      scale: kStartScale + (1 - kStartScale) * Curves.easeOutCubic.transform(p),
    );
  }

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _BrandFadeTransition(
      animation: animation,
      animate: !MediaQuery.disableAnimationsOf(context),
      child: child,
    );
  }
}

class _BrandFadeTransition extends StatelessWidget {
  const _BrandFadeTransition({
    required this.animation,
    required this.animate,
    required this.child,
  });

  final Animation<double> animation;
  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Mesma árvore em todos os quadros (e com/sem reduzir movimento) para a
    // página não perder estado; `child` não é reconstruído a cada quadro.
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final frame = BrandFadePageTransitionsBuilder.frameAt(
          animate ? animation.value : 1,
        );
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: frame.overlay),
          ),
          child: Opacity(
            opacity: frame.pageVisible ? 1 : 0,
            child: Transform.scale(scale: frame.scale, child: child),
          ),
        );
      },
      child: child,
    );
  }
}
