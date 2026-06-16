import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import 'light_beam.dart';

/// Título PLPCG com feixe de luz dourado sob as letras (light-beam §6.2).
///
/// Usado em [PlpcgPrimaryAppBar] ([ShellScaffold]) e na barra 1 do leitor
/// ([PdfReaderScreen]).
class PlpcgAppBarTitle extends StatelessWidget {
  const PlpcgAppBarTitle({
    this.showLightBeam = true,
    super.key,
  });

  /// Exibe o feixe dourado sob a marca (AppBar). Desligado no folheto impresso.
  final bool showLightBeam;

  static const _lightBeamTop = 33.0;
  static const _lightBeamWidth = 170.0;
  static const _titleHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _titleHeight,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          if (showLightBeam)
            const Positioned(
              top: _lightBeamTop,
              child: LightBeam(width: _lightBeamWidth, height: 16),
            ),
          const Text('PLPCG', style: AppTypography.displayPlcpg),
        ],
      ),
    );
  }
}
