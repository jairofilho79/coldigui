import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Troca para um destino da bottom bar ([RoutePaths] de aba).
///
/// Usar `go`, nunca `push` — push empilha na branch atual do
/// [StatefulShellRoute] sem atualizar a aba selecionada.
void goToShellDestination(BuildContext context, String location) {
  context.go(location);
}
