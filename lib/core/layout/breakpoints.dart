import 'package:flutter/widgets.dart';

/// Largura mínima para o split view do leitor (A.6) e para a cifra em duas
/// colunas (C9).
const double kWideLayoutBreakpoint = 900;

/// Largura mínima para o rail de navegação do shell, abaixo de
/// [kWideLayoutBreakpoint].
const double kRailBreakpoint = 840;

/// `true` quando [width] já cabe o layout largo.
bool isWideWidth(double width) => width >= kWideLayoutBreakpoint;

/// `true` quando a largura atual de [context] já cabe o layout largo.
bool isWideLayout(BuildContext context) =>
    isWideWidth(MediaQuery.sizeOf(context).width);
