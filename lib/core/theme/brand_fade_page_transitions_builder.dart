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
/// Push: a rota de cima faz tudo ([frameAt]); a de baixo fica parada.
/// Pop tem coreografia própria — tocar o push ao contrário deixava a tela de
/// cima encolhendo com a borda da de baixo à mostra e as curvas invertidas
/// (lento no começo, brusco no fim): a cor cobre a tela de cima rápido e sem
/// mexer na escala ([popFrameAt]) e a tela de baixo, pelo
/// `secondaryAnimation`, se revela crescendo como no push ([revealScaleAt]).
/// Com "reduzir movimento" ([MediaQuery.disableAnimationsOf]) a página
/// aparece inteira de imediato.
class BrandFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const BrandFadePageTransitionsBuilder();

  /// Duração total (ida e volta).
  static const int kTransitionMilliseconds = 240;

  /// Fração da animação em que a cor cobre tudo e a página nova passa a
  /// ser pintada — antes, só a cor subindo; depois, a página se revelando.
  static const double kMidpoint = 0.4;

  /// Como [kMidpoint], para o pop: cobrir a tela que sai é mais curto que
  /// revelar a que volta.
  static const double kPopMidpoint = 0.35;

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

  /// Estado visual da rota que sai num pop, em [q] (progresso 0–1 do pop).
  static BrandFadeFrame popFrameAt(double q) {
    if (q < kPopMidpoint) {
      return (
        overlay: Curves.easeOut.transform(q / kPopMidpoint),
        pageVisible: true,
        scale: 1,
      );
    }
    final p = (q - kPopMidpoint) / (1 - kPopMidpoint);
    return (
      overlay: 1 - Curves.easeOut.transform(p),
      pageVisible: false,
      scale: 1,
    );
  }

  /// Escala da rota de baixo num pop, em [q] (progresso 0–1 do pop): parada
  /// em [kStartScale] enquanto está coberta, cresce até 100% na revelação.
  static double revealScaleAt(double q) {
    if (q < kPopMidpoint) return kStartScale;
    final p = (q - kPopMidpoint) / (1 - kPopMidpoint);
    return kStartScale + (1 - kStartScale) * Curves.easeOutCubic.transform(p);
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
      secondaryAnimation: secondaryAnimation,
      animate: !MediaQuery.disableAnimationsOf(context),
      child: child,
    );
  }
}

class _BrandFadeTransition extends StatelessWidget {
  const _BrandFadeTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.animate,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Mesma árvore em todos os quadros (e com/sem reduzir movimento) para a
    // página não perder estado; `child` não é reconstruído a cada quadro.
    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      builder: (context, child) {
        final frame = !animate
            ? BrandFadePageTransitionsBuilder.frameAt(1)
            : animation.status == AnimationStatus.reverse
            ? BrandFadePageTransitionsBuilder.popFrameAt(1 - animation.value)
            : BrandFadePageTransitionsBuilder.frameAt(animation.value);
        // Rota de baixo durante o pop da de cima.
        final revealScale =
            animate && secondaryAnimation.status == AnimationStatus.reverse
            ? BrandFadePageTransitionsBuilder.revealScaleAt(
                1 - secondaryAnimation.value,
              )
            : 1.0;
        final scale = frame.scale * revealScale;
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: frame.overlay),
          ),
          // Fundo sob a rota de baixo reduzida no pop: a borda que sobra fica
          // marrom, e não o que houver abaixo (vazio no navigator raiz). Só
          // nela — no push a cor sobe por cima da página parada.
          child: ColoredBox(
            color: revealScale < 1 ? AppColors.background : Colors.transparent,
            child: Opacity(
              opacity: frame.pageVisible ? 1 : 0,
              child: Transform.scale(scale: scale, child: child),
            ),
          ),
        );
      },
      child: child,
    );
  }
}
