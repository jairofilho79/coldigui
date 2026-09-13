import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/utils/louvor_search_tokens.dart';
import 'package:flutter/material.dart';

/// Texto com o termo buscado destacado — usado no título do card (C5).
///
/// A normalização é a mesma do índice de busca ([LouvorSearchTokens.normalize]
/// — UC-01): acento-insensível, case-insensível. [text] mantém a grafia
/// original; só o pedaço casado ganha [highlightStyle] (padrão: cor ouro do
/// tema, sem cor nova).
///
/// [query] vazia (ou sem match) devolve [text] sem nenhum destaque.
class HighlightedText extends StatelessWidget {
  const HighlightedText({
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
    this.maxLines,
    this.overflow,
    super.key,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  static const _defaultHighlightStyle = TextStyle(
    color: AppColors.gold,
    fontWeight: FontWeight.w700,
  );

  /// Ocorrências de [query] (normalizada) em [text] — pares `[início, fim)`.
  ///
  /// [LouvorSearchTokens.normalize] troca cada caractere por exatamente um
  /// outro (minúsculas + acentos), então os índices da string normalizada
  /// valem também para [text] original.
  static List<(int, int)> _matches(String text, String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty || text.isEmpty) return const [];

    final normalizedText = LouvorSearchTokens.normalize(text);
    final normalizedQuery = LouvorSearchTokens.normalize(trimmedQuery);
    if (normalizedQuery.isEmpty) return const [];

    final matches = <(int, int)>[];
    var start = 0;
    while (start <= normalizedText.length) {
      final index = normalizedText.indexOf(normalizedQuery, start);
      if (index < 0) break;
      final end = index + normalizedQuery.length;
      matches.add((index, end));
      start = end;
    }
    return matches;
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches(text, query);
    if (matches.isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }

    final resolvedHighlightStyle = highlightStyle ?? _defaultHighlightStyle;
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final (start, end) in matches) {
      if (start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: resolvedHighlightStyle,
        ),
      );
      cursor = end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
