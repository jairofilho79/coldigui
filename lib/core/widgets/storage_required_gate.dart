import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/app_localizations.dart';
import '../database/isar_provider.dart';
import '../theme/app_typography.dart';
import '../theme/color_extensions.dart';

/// Bloqueia [child] enquanto o Isar não está pronto.
///
/// Com o app montado durante a abertura (A8), [IsarStatus.opening] passou a ser
/// um estado visível: mostra spinner em vez do aviso de indisponível, que
/// mentiria durante os segundos de WASM + OPFS de um boot web frio.
class StorageRequiredGate extends ConsumerWidget {
  const StorageRequiredGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    switch (ref.watch(isarStatusProvider)) {
      case IsarStatus.available:
        return child;
      case IsarStatus.opening:
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _PulsingLogo(),
                  const SizedBox(height: 20),
                  Text(
                    l10n.storagePreparing,
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case IsarStatus.unavailable:
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.storage_outlined,
                    color: AppColors.gold,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.storageUnavailableTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.headline.copyWith(
                      color: AppColors.title,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.storageUnavailableBody,
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => ref.invalidate(isarInitializerProvider),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }
}

/// Logo PLPCG usada como indicador de carregamento: opacidade e o halo
/// dourado atrás dela "respiram" em loop enquanto o Isar abre — substitui o
/// spinner genérico, na mesma linguagem visual da splash web (`web/index.html`).
class _PulsingLogo extends StatefulWidget {
  const _PulsingLogo();

  static const _logoAsset = 'assets/branding/logo_colorido_no_bg_logo_only.svg';
  static const _size = 140.0;

  @override
  State<_PulsingLogo> createState() => _PulsingLogoState();
}

class _PulsingLogoState extends State<_PulsingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        final glowOpacity = lerpDouble(0.3, 0.6, _t.value)!;
        final glowScale = lerpDouble(0.6, 0.85, _t.value)!;
        final logoOpacity = lerpDouble(0.35, 0.7, _t.value)!;
        return SizedBox(
          width: _PulsingLogo._size,
          height: _PulsingLogo._size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: glowOpacity,
                child: Transform.scale(
                  scale: glowScale,
                  child: Container(
                    width: _PulsingLogo._size,
                    height: _PulsingLogo._size,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0xE6FFFBEA),
                          Color(0x8CFFD96B),
                          Color(0x00D4AF37),
                        ],
                        stops: [0.0, 0.45, 0.72],
                      ),
                    ),
                  ),
                ),
              ),
              Opacity(opacity: logoOpacity, child: child),
            ],
          ),
        );
      },
      child: SvgPicture.asset(
        _PulsingLogo._logoAsset,
        width: _PulsingLogo._size,
        height: _PulsingLogo._size,
        fit: BoxFit.contain,
      ),
    );
  }
}
