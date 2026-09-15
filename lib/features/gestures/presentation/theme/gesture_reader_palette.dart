import 'package:flutter/material.dart';

/// Cores de uma variante (clara/escura) do papel de gestos.
///
/// Escolhida por `GestureReaderMode.palette` e passada por parâmetro a cada
/// widget do leitor — nenhum deles lê tema global. A figura fica sempre em
/// quadro branco ([figureBg]): os PNGs do dicionário são coloridos, com borda
/// preta desenhada dentro da imagem, e não admitem inversão.
class GestureReaderPalette {
  const GestureReaderPalette({
    required this.paper,
    required this.stripe,
    required this.trigger,
    required this.lyric,
    required this.blue,
    required this.orange,
    required this.wine,
    required this.instructionBg,
    required this.instructionText,
    required this.instructionBorder,
    required this.sectionLabel,
    required this.placeholderBg,
    required this.placeholderBorder,
    required this.figureBg,
    required this.figureBorder,
    required this.toolbarIcon,
    required this.divider,
  });

  /// Fundo da página.
  final Color paper;

  /// Faixa de fundo dos cartões ímpares (zebra).
  final Color stripe;

  /// Gatilho: palavra em que o gesto começa.
  final Color trigger;

  /// Leitura: o que se canta enquanto o gesto dura. Também o título.
  final Color lyric;

  /// Chave de repetição, `Nx`, rótulo `CORO`, chips do foco.
  final Color blue;

  /// Conector de ligação.
  final Color orange;

  /// Divisor e rótulo `FINAL`.
  final Color wine;

  final Color instructionBg;
  final Color instructionText;
  final Color instructionBorder;

  /// Rótulo de seção da leitura linear e linha livre (`text`).
  final Color sectionLabel;

  final Color placeholderBg;
  final Color placeholderBorder;

  /// Quadro da figura — branco nos dois temas.
  final Color figureBg;
  final Color figureBorder;

  /// Ícones da barra 3.
  final Color toolbarIcon;

  /// Separadores da barra e rodapé do foco.
  final Color divider;
}

/// Fonte em que a figura tem 96 dp de lado.
const double kGestureBaseFontSize = 18;

/// Lado da caixa da figura para [fontSize]: `96 × (fonte / 18)`.
double gestureFigureSide(double fontSize) => 96 * fontSize / kGestureBaseFontSize;

/// Gap vertical entre cartões e entre blocos (spec §4).
const double kGestureCardGap = 12;
const double kGestureBlockGap = 20;

/// Largura da coluna da chave (`repeat`/`coro`) e do conector (`link`).
const double kGestureBraceWidth = 28;
const double kGestureLinkWidth = 20;

/// Página: largura máxima e margens.
const double kGesturePageMaxWidth = 720;
const double kGesturePageMargin = 16;
