import 'dart:convert';

import '../entities/gesture_document.dart';

/// Falha **conclusiva** de parse: corpo que não é JSON ou raiz que não é
/// objeto. Só nesses dois casos não há nada para renderizar; tudo o que
/// acontece dentro de `items` é tolerado item a item, porque o leitor não
/// pode cair no meio do culto por causa de um campo torto.
class GestureDocumentParseException implements Exception {
  const GestureDocumentParseException(this.message);

  final String message;

  @override
  String toString() => 'GestureDocumentParseException: $message';
}

/// Máximo de linhas de letra por cartão (contrato §3.1).
const kGestureMaxLyricLines = 3;

/// Parseia o JSON de um documento de gestos.
///
/// Lança [GestureDocumentParseException] só para JSON inválido / raiz não
/// objeto. Regras de tolerância: spec §3.3.
GestureDocument parseGestureDocument(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException catch (error) {
    throw GestureDocumentParseException('JSON inválido: ${error.message}');
  }
  if (decoded is! Map<String, Object?>) {
    throw GestureDocumentParseException('raiz não é objeto');
  }

  final rawItems = decoded['items'];
  return GestureDocument(
    schemaMajor: parseSchemaMajor(decoded['schema']),
    title: _asTrimmedString(decoded['title']),
    dictionaryVersion: _asInt(decoded['dictionaryVersion']) ?? 0,
    items: rawItems is List<Object?> ? _parseItems(rawItems) : const [],
  );
}

/// `"coldigom.gestures/1"` → 1. Ausente ou ilegível assume 1: a alternativa
/// (tratar como mais novo) mostraria o aviso de atualização à toa.
int parseSchemaMajor(Object? schema) {
  if (schema is! String) return 1;
  final slash = schema.lastIndexOf('/');
  if (slash == -1) return 1;
  final version = schema.substring(slash + 1);
  final dot = version.indexOf('.');
  final major = int.tryParse(dot == -1 ? version : version.substring(0, dot));
  return major ?? 1;
}

List<GestureItem> _parseItems(List<Object?> raw) {
  return [
    for (final entry in raw) ?_parseItem(entry),
  ];
}

GestureItem? _parseItem(Object? raw) {
  if (raw is! Map<String, Object?>) return null;

  switch (raw['type']) {
    case 'gesture':
      return GestureCard(
        gestureId: _asTrimmedString(raw['gestureId']),
        lyrics: _parseLyrics(raw['lyrics']),
      );
    case 'repeat':
      final children = _parseChildren(raw['children']);
      if (children.isEmpty) return null;
      final count = _asInt(raw['count']);
      return RepeatBlock(
        count: count == null || count < 2 ? 2 : count,
        children: children,
      );
    case 'coro':
      final children = _parseChildren(raw['children']);
      return children.isEmpty ? null : ChorusBlock(children: children);
    case 'link':
      final children = _parseChildren(raw['children']);
      return children.isEmpty ? null : LinkBlock(children: children);
    case 'final':
      final children = _parseChildren(raw['children']);
      return children.isEmpty ? null : FinalBlock(children: children);
    case 'instruction':
      final kind = _instructionKind(raw['kind']);
      return kind == null ? TextLine(jsonEncode(raw)) : InstructionCard(kind);
    case 'text':
      final text = _asTrimmedString(raw['text']);
      return text.isEmpty ? null : TextLine(text);
    default:
      // Tipo desconhecido: se trouxer `text`, é o que se mostra; senão o
      // JSON compactado, para o regente ver que algo ficou de fora.
      final text = _asTrimmedString(raw['text']);
      return TextLine(text.isEmpty ? jsonEncode(raw) : text);
  }
}

List<GestureItem> _parseChildren(Object? raw) {
  if (raw is! List<Object?>) return const [];
  return _parseItems(raw);
}

List<LyricLine> _parseLyrics(Object? raw) {
  const fallback = [LyricLine(trigger: '', text: '')];
  if (raw is! List<Object?>) return fallback;
  final lines = <LyricLine>[];
  for (final entry in raw) {
    if (entry is! Map<String, Object?>) continue;
    lines.add(
      LyricLine(
        trigger: _asTrimmedString(entry['trigger']),
        text: _asTrimmedString(entry['text']),
      ),
    );
    if (lines.length == kGestureMaxLyricLines) break;
  }
  return lines.isEmpty ? fallback : lines;
}

InstructionKind? _instructionKind(Object? raw) => switch (raw) {
  'instruments' => InstructionKind.instruments,
  'repeat_praise' => InstructionKind.repeatPraise,
  'back_to_chorus' => InstructionKind.backToChorus,
  'back_to_chorus_and_finish' => InstructionKind.backToChorusAndFinish,
  _ => null,
};

String _asTrimmedString(Object? value) => value is String ? value.trim() : '';

int? _asInt(Object? value) => switch (value) {
  int() => value,
  num() => value.toInt(),
  String() => int.tryParse(value.trim()),
  _ => null,
};
