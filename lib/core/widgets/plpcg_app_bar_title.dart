import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import 'light_beam.dart';

/// Título PLPCG com feixe de luz dourado sob as letras (light-beam §6.2).
///
/// Usado em [PlpcgPrimaryAppBar] ([ShellScaffold]) e na barra 1 do leitor
/// ([PdfReaderScreen]).
class PlpcgAppBarTitle extends StatelessWidget {
  const PlpcgAppBarTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            top: 33,
            child: LightBeam(width: 170, height: 16),
          ),
          const Text('PLPCG', style: AppTypography.displayPlcpg),
        ],
      ),
    );
  }
}
