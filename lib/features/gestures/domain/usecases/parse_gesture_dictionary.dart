import 'dart:convert';

import '../entities/gesture_dictionary.dart';

/// Falha conclusiva de parse do dicionário (JSON inválido / raiz não objeto).
class GestureDictionaryParseException implements Exception {
  const GestureDictionaryParseException(this.message);

  final String message;

  @override
  String toString() => 'GestureDictionaryParseException: $message';
}

/// Parseia o JSON de `GET /api/gestures/dictionary`.
///
/// Entrada sem `id` ou sem `image` é descartada (não há o que desenhar);
/// `status` desconhecido vira `active`; campos ausentes ganham vazio/null.
GestureDictionary parseGestureDictionary(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException catch (error) {
    throw GestureDictionaryParseException('JSON inválido: ${error.message}');
  }
  if (decoded is! Map<String, Object?>) {
    throw GestureDictionaryParseException('raiz não é objeto');
  }

  final byId = <String, GestureEntry>{};
  final rawGestures = decoded['gestures'];
  if (rawGestures is List<Object?>) {
    for (final raw in rawGestures) {
      final entry = _parseEntry(raw);
      if (entry != null) byId[entry.id] = entry;
    }
  }

  final rawVersion = decoded['version'];
  return GestureDictionary(
    version: rawVersion is num ? rawVersion.toInt() : 0,
    generatedAt: _parseDate(decoded['generatedAt']),
    byId: byId,
  );
}

GestureEntry? _parseEntry(Object? raw) {
  if (raw is! Map<String, Object?>) return null;
  final id = _string(raw['id']);
  final image = _string(raw['image']);
  if (id.isEmpty || image.isEmpty) return null;

  final gif = _string(raw['gif']);
  final replacedBy = _string(raw['replacedBy']);
  final rawTriggers = raw['exampleTriggers'];
  return GestureEntry(
    id: id,
    name: _string(raw['name']),
    description: _string(raw['description']),
    exampleTriggers: rawTriggers is List<Object?>
        ? [for (final t in rawTriggers) if (t is String) t]
        : const [],
    image: image,
    gif: gif.isEmpty ? null : gif,
    status: raw['status'] == 'deprecated'
        ? GestureStatus.deprecated
        : GestureStatus.active,
    replacedBy: replacedBy.isEmpty ? null : replacedBy,
    updatedAt: _parseDate(raw['updatedAt']),
  );
}

DateTime? _parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

String _string(Object? value) => value is String ? value.trim() : '';
