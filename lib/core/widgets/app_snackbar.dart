import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Largura máxima do snackbar flutuante (auditoria P8).
///
/// Em tela larga (1568 px medidos em produção) o snackbar de 100 % da
/// largura punha texto e ação nos cantos opostos da tela.
const double kAppSnackbarMaxWidth = 480;

/// Margem lateral mínima em telas estreitas — igual ao `margin` padrão do
/// `SnackBarBehavior.floating` (16 px de cada lado).
const double _kAppSnackbarSideMargin = 16;

/// Largura do snackbar para uma tela de [screenWidth]: no máximo
/// [kAppSnackbarMaxWidth], e nunca maior que a tela menos as margens.
double appSnackbarWidth(double screenWidth) =>
    math.min(kAppSnackbarMaxWidth, screenWidth - 2 * _kAppSnackbarSideMargin);

/// Exibe toast via [SnackBar] (substitui AppSnackbarHost do SvelteKit).
///
/// Flutuante, com largura limitada por [appSnackbarWidth]. [action] aparece
/// à direita do texto; [clearPrevious] descarta o snackbar em exibição em vez
/// de enfileirar (o padrão do [ScaffoldMessenger] é a fila).
void showAppSnackbar(
  BuildContext context,
  String message, {
  SnackBarAction? action,
  bool clearPrevious = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  if (clearPrevious) messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      action: action,
      behavior: SnackBarBehavior.floating,
      width: appSnackbarWidth(MediaQuery.sizeOf(context).width),
    ),
  );
}

/// Limpa os snackbars pendentes assim que a tela terminar de montar.
///
/// Para os leitores (`/leitor`, `/cifra`, `/gestos`): o «Adicionado à lista»
/// da Home sobrevivia ao push e cobria o rodapé da partitura (auditoria P8).
/// Chamar no `initState` — o [ScaffoldMessenger] só pode ser lido depois do
/// primeiro frame, por isso o pós-frame.
void clearSnackbarsOnEnter(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
  });
}
