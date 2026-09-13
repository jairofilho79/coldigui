import 'package:flutter/material.dart';

/// Cores do papel de gestos (spec §4) — **isoladas** do `AppColors`.
///
/// O documento é desenhado sempre sobre branco porque as figuras são PNG com
/// fundo branco; o tema vinho/creme do app fica no chrome ao redor. O preview
/// do editor no coldigom usa exatamente estes valores.
abstract final class GestureReaderPalette {
  static const Color paper = Color(0xFFFFFFFF);

  /// Gatilho: palavra em que o gesto começa.
  static const Color trigger = Color(0xFFD32F2F);

  /// Leitura: o que se canta enquanto o gesto dura.
  static const Color lyric = Color(0xFF1A1A1A);

  /// Chave de repetição, `Nx`, rótulo `CORO`, chave tracejada.
  static const Color blue = Color(0xFF1E63C8);

  /// Conector de ligação.
  static const Color orange = Color(0xFFE08A1E);

  /// Divisor e rótulo `FINAL`.
  static const Color wine = Color(0xFF6A2F2F);

  static const Color instructionBg = Color(0xFFF3F4F6);
  static const Color instructionText = Color(0xFF374151);
  static const Color instructionBorder = Color(0xFFD1D5DB);

  static const Color placeholderBg = Color(0xFFFFF7E6);
  static const Color placeholderBorder = Color(0xFFE0B45C);

  /// Linha livre (`text`).
  static const Color freeText = Color(0xFF6B7280);
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
